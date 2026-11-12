import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/agent_thread.dart';
import '../utils/thread_transcript.dart';
import 'agent_threads_controller.dart';
import 'thread_wire.dart';

/// Loads one page of a child session's stored transcript: [limit] rows,
/// [offset] rows back from the newest, each page in chronological order.
typedef ThreadHistoryPageLoader =
    Future<List<Map<String, dynamic>>> Function(
      String childSessionId, {
      required int limit,
      required int offset,
    });

/// Where the stored transcript of a finished thread stands.
enum ThreadHistoryStatus {
  /// Not requested: the thread is still running.
  idle,
  loading,
  loaded,

  /// Loaded, but not all of it: older rows could not be read.
  partial,

  /// Nothing could be loaded.
  unavailable,
}

/// The content of one thread view.
///
/// While the thread runs and the view is visible, `subagent.tail` is polled
/// every [pollInterval] and again whenever a thread event reports a new
/// step. When the thread ends the view switches to the child session's
/// stored transcript. If that cannot be read, or only partly, the view keeps
/// what it has and says so; it never becomes an error screen.
class ThreadViewController extends ChangeNotifier {
  ThreadViewController({
    required this.threads,
    required this.threadId,
    required this.loadHistory,
    this.pollInterval = const Duration(seconds: 2),
    this.pageSize = 200,
    this.maxPages = 5,
  }) {
    _lastState = thread?.state;
    _lastToolCount = thread?.toolCount ?? 0;
    threads.addListener(_onThreadsChanged);
  }

  final AgentThreadsController threads;
  final String threadId;
  final ThreadHistoryPageLoader? loadHistory;
  final Duration pollInterval;
  final int pageSize;
  final int maxPages;

  Timer? _timer;
  bool _visible = false;
  bool _disposed = false;
  bool _polling = false;
  bool _pollAgain = false;
  AgentThreadState? _lastState;
  int _lastToolCount = 0;
  String? _historySessionId;
  int _historyGeneration = 0;

  ThreadTranscript _live = ThreadTranscript.empty;
  bool _tailTruncated = false;
  ThreadTranscript _history = ThreadTranscript.empty;
  ThreadHistoryStatus _historyStatus = ThreadHistoryStatus.idle;

  AgentThread? get thread => threads.thread(threadId);

  /// The view is on screen and its thread has a live agent.
  bool get isLive => thread?.state.isLive ?? false;

  /// Whether the tail is being polled right now.
  bool get isPolling => _timer != null;

  ThreadHistoryStatus get historyStatus => _historyStatus;

  /// The live tail no longer reaches back to the thread's first steps.
  bool get tailTruncated => _tailTruncated && !_showsHistory;

  bool get _showsHistory =>
      _historyStatus == ThreadHistoryStatus.loaded ||
      _historyStatus == ThreadHistoryStatus.partial;

  /// What to show: the stored transcript once it has loaded, the live tail
  /// until then.
  ThreadTranscript get transcript => _showsHistory ? _history : _live;

  /// The task the coordinator gave the thread.
  String? get task {
    final fromTranscript = transcript.task?.trim() ?? '';
    if (fromTranscript.isNotEmpty) return fromTranscript;
    final goal = thread?.goal.trim() ?? '';
    return goal.isEmpty ? null : goal;
  }

  /// Tells the controller whether its view is on screen. Polling only runs
  /// while it is.
  void setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    _sync();
  }

  void _onThreadsChanged() {
    final current = thread;
    final state = current?.state;
    final toolCount = current?.toolCount ?? 0;
    final stateChanged = state != _lastState;
    final stepped = toolCount != _lastToolCount;
    _lastState = state;
    _lastToolCount = toolCount;
    if (stateChanged) {
      _sync();
    } else if (stepped && _timer != null) {
      // An event reported a new step: do not wait for the next tick.
      unawaited(_poll());
    }
    _notify();
  }

  void _sync() {
    final live = isLive;
    if (_visible && live) {
      // A thread that runs again (a follow-up) leaves its old transcript.
      if (_historyStatus != ThreadHistoryStatus.idle) {
        _historyGeneration += 1;
        _historyStatus = ThreadHistoryStatus.idle;
        _history = ThreadTranscript.empty;
        _historySessionId = null;
        _live = ThreadTranscript.empty;
      }
      if (_timer == null) {
        _timer = Timer.periodic(pollInterval, (_) => unawaited(_poll()));
        unawaited(_poll());
      }
    } else {
      _timer?.cancel();
      _timer = null;
      final current = thread;
      if (_visible && current != null && current.state.isFinished) {
        unawaited(_loadHistory());
      }
    }
    _notify();
  }

  Future<void> _poll() async {
    if (_polling) {
      _pollAgain = true;
      return;
    }
    _polling = true;
    try {
      do {
        _pollAgain = false;
        final ThreadTailSnapshot tail;
        try {
          tail = await threads.tail(threadId);
        } catch (_) {
          // A dropped socket or a thread that just ended. The next tick, or
          // the hand-over to stored history, covers it.
          break;
        }
        if (_disposed || _timer == null) break;
        if (!tail.available) continue;
        _tailTruncated = tail.truncated;
        _live = ThreadTranscript.fromTail(
          ThreadTailLine.parseAll(tail.text),
          fallbackTask: thread?.goal,
        );
        _notify();
      } while (_pollAgain && !_disposed && _timer != null);
    } finally {
      _polling = false;
    }
  }

  /// Reads the stored transcript again, after a failed or partial load.
  Future<void> retryHistory() {
    _historySessionId = null;
    return _loadHistory();
  }

  Future<void> _loadHistory() async {
    final loader = loadHistory;
    final sessionId = thread?.childSessionId;
    if (loader == null || sessionId == null || sessionId.isEmpty) {
      if (_historyStatus != ThreadHistoryStatus.unavailable) {
        _historyStatus = ThreadHistoryStatus.unavailable;
        _notify();
      }
      return;
    }
    if (_historySessionId == sessionId &&
        _historyStatus != ThreadHistoryStatus.idle) {
      return;
    }
    _historySessionId = sessionId;
    final generation = ++_historyGeneration;
    _historyStatus = ThreadHistoryStatus.loading;
    _notify();

    final pages = <List<Map<String, dynamic>>>[];
    var offset = 0;
    var more = true;
    var failedPage = false;
    while (more && pages.length < maxPages) {
      try {
        final page = await loader(sessionId, limit: pageSize, offset: offset);
        if (_disposed || generation != _historyGeneration) return;
        pages.add(page);
        offset += page.length;
        more = page.length == pageSize;
      } catch (_) {
        if (_disposed || generation != _historyGeneration) return;
        failedPage = true;
        break;
      }
    }
    if (pages.isEmpty) {
      _historyStatus = ThreadHistoryStatus.unavailable;
      _notify();
      return;
    }
    // Pages run newest first; rows inside a page are chronological.
    final rows = pages.reversed.expand((page) => page).toList();
    _history = ThreadTranscript.fromHistory(rows);
    _historyStatus = failedPage || more
        ? ThreadHistoryStatus.partial
        : ThreadHistoryStatus.loaded;
    if (_history.isEmpty && _history.task == null && !_live.isEmpty) {
      // The stored session exists but holds nothing yet: the tail is the
      // better account.
      _historyStatus = ThreadHistoryStatus.unavailable;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    threads.removeListener(_onThreadsChanged);
    super.dispose();
  }
}
