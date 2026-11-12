import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/agent_thread.dart';
import '../models/gateway_insight.dart';
import 'capability_registry.dart';
import 'desktop_gateway_client.dart';
import 'thread_wire.dart';
import 'ws_client.dart';

/// Which thread features the connected gateway offers.
@immutable
class ThreadSupport {
  const ThreadSupport({
    this.roster = false,
    this.steer = false,
    this.messages = false,
    this.continueThreads = false,
    this.approvals = false,
    this.coordinatorMode = false,
  });

  /// Nothing: an old gateway, or no gateway. The read-only task list stays.
  static const none = ThreadSupport();

  /// A stock gateway that passed the roster probe.
  static const stock = ThreadSupport(roster: true, steer: true);

  /// A gateway with every `coordinator-threads` capability.
  static const full = ThreadSupport(
    roster: true,
    steer: true,
    messages: true,
    continueThreads: true,
    approvals: true,
    coordinatorMode: true,
  );

  factory ThreadSupport.of(CapabilityRegistry registry) => ThreadSupport(
    roster: registry.threadsRoster,
    steer: registry.threadsSteer,
    messages: registry.threadsMessages,
    continueThreads: registry.threadsContinue,
    approvals: registry.threadsApprovals,
    coordinatorMode: registry.coordinatorMode,
  );

  /// Roster, strip, sheet and thread view.
  final bool roster;

  /// Steer and stop.
  final bool steer;

  /// Update and question cards, and replying to a question.
  final bool messages;

  /// Continuing a finished thread.
  final bool continueThreads;

  /// Approvals that name the thread that raised them.
  final bool approvals;

  /// The per-chat coordinator flag.
  final bool coordinatorMode;
}

/// The gateway calls the thread UI makes for one chat.
///
/// [DesktopThreadsGateway] is the real one. Tests pass a fake.
abstract class AgentThreadsGateway {
  ThreadSupport get support;

  /// Notifies when [support] may have changed.
  Listenable? get supportChanges;

  /// Probes thread support on a gateway that advertises none. A no-op when
  /// support is already known for this connection.
  Future<void> probe();

  Future<ThreadRosterSnapshot> listThreads();
  Future<DelegationStatusSnapshot> delegationStatus();
  Future<bool> setPaused(bool paused);
  Future<ThreadTailSnapshot> tail(String subagentId);
  Future<ThreadSteerResult> steer(String subagentId, String text);
  Future<ThreadInterruptResult> interrupt(String subagentId);
  Future<void> reply({
    required String subagentId,
    required String questionId,
    required String text,
  });
  Future<ThreadContinueResult> continueThread(String subagentId, String text);

  /// Binds the chat's gateway session, which is also when the gateway's
  /// capabilities become known.
  Future<void> ensureSession();
  Future<CoordinatorModeResult> setCoordinatorMode(bool coordinator);
}

/// [AgentThreadsGateway] over a chat's [DesktopGatewayClient].
class DesktopThreadsGateway implements AgentThreadsGateway {
  DesktopThreadsGateway(
    this._client, {
    required this.sessionId,
    this.workingDirectory,
  });

  final DesktopGatewayClient _client;

  /// The chat's mobile session id.
  final String sessionId;
  final String? workingDirectory;

  @override
  ThreadSupport get support => ThreadSupport.of(_client.capabilities);

  @override
  Listenable get supportChanges => _client.capabilities;

  @override
  Future<void> probe() => _client.probeThreadSupport(sessionId);

  @override
  Future<ThreadRosterSnapshot> listThreads() => _client.listThreads(sessionId);

  @override
  Future<DelegationStatusSnapshot> delegationStatus() =>
      _client.delegationStatus();

  @override
  Future<bool> setPaused(bool paused) => _client.setDelegationPaused(paused);

  @override
  Future<ThreadTailSnapshot> tail(String subagentId) =>
      _client.tailThread(sessionId: sessionId, subagentId: subagentId);

  @override
  Future<ThreadSteerResult> steer(String subagentId, String text) => _client
      .steerThread(sessionId: sessionId, subagentId: subagentId, text: text);

  @override
  Future<ThreadInterruptResult> interrupt(String subagentId) =>
      _client.interruptThread(sessionId: sessionId, subagentId: subagentId);

  @override
  Future<void> reply({
    required String subagentId,
    required String questionId,
    required String text,
  }) => _client.replyToThread(
    sessionId: sessionId,
    subagentId: subagentId,
    questionId: questionId,
    text: text,
  );

  @override
  Future<ThreadContinueResult> continueThread(String subagentId, String text) =>
      _client.continueThread(
        sessionId: sessionId,
        subagentId: subagentId,
        text: text,
      );

  @override
  Future<void> ensureSession() =>
      _client.ensureSession(sessionId, workingDirectory: workingDirectory);

  @override
  Future<CoordinatorModeResult> setCoordinatorMode(bool coordinator) => _client
      .setCoordinatorMode(sessionId: sessionId, coordinator: coordinator);
}

/// Where a steer the user sent stands.
enum ThreadSteerStatus {
  sending,

  /// Queued by the gateway for the thread's next step.
  sent,

  /// The thread took another step after the steer was queued.
  acknowledged,

  /// The thread finished, or refused, before the steer could apply.
  didNotLand,
}

@immutable
class ThreadSteerRecord {
  const ThreadSteerRecord({required this.text, required this.status});

  final String text;
  final ThreadSteerStatus status;
}

/// How a thread question stands, as far as this device knows.
enum ThreadQuestionState {
  /// The thread is waiting for an answer.
  pending,

  /// "Let coordinator decide" was sent; the coordinator has not answered yet.
  deciding,
  answered,
  expired,

  /// The thread stopped waiting: it was stopped, or it finished.
  cancelled,

  /// No longer open, and this device did not see how it ended.
  closed,
}

@immutable
class ThreadQuestionRecord {
  const ThreadQuestionRecord({
    required this.subagentId,
    required this.state,
    this.answer,
    this.answeredBy,
  });

  final String subagentId;
  final ThreadQuestionState state;
  final String? answer;
  final ThreadAnsweredBy? answeredBy;

  bool get isOpen =>
      state == ThreadQuestionState.pending ||
      state == ThreadQuestionState.deciding;
}

/// The reply could not be delivered because the question is no longer open.
class ThreadQuestionClosedException implements Exception {
  const ThreadQuestionClosedException(this.message);

  /// The gateway's explanation: who answered, or that the wait ended.
  final String message;

  @override
  String toString() => message;
}

/// The threads of one chat.
///
/// `subagent.list` seeds the roster when the chat binds and after every
/// reconnect; `subagent.*` events update it in between. The seed is what
/// repairs an event missed while the socket was down. The controller also
/// keeps the read-only task list an old gateway still gets.
class AgentThreadsController extends ChangeNotifier {
  AgentThreadsController({
    AgentThreadsGateway? gateway,
    DateTime Function()? clock,
  }) : _gateway = gateway,
       _clock = clock ?? DateTime.now {
    gateway?.supportChanges?.addListener(_onSupportChanged);
    _support = gateway?.support ?? ThreadSupport.none;
  }

  final AgentThreadsGateway? _gateway;
  final DateTime Function() _clock;
  final Map<String, AgentThread> _threads = {};
  final List<GatewaySubagentActivity> _legacyActivities = [];
  final Map<String, ThreadQuestionRecord> _questions = {};
  final List<ThreadMessageAnnotation> _liveMessages = [];
  final Map<String, ThreadSteerRecord> _steers = {};
  final Map<String, int> _queuePositions = {};
  ThreadSupport _support = ThreadSupport.none;
  Future<void>? _seeding;
  bool _disposed = false;
  bool _paused = false;
  int? _slotsInUse;
  int? _slotLimit;
  String? _slotModel;

  /// Called when an event ends a thread, for a notification.
  void Function(AgentThread thread)? onThreadFinished;

  /// Called when a thread asks a question, for a notification.
  void Function(AgentThread thread, AgentThreadQuestion question)?
  onThreadQuestion;

  AgentThreadsGateway? get gateway => _gateway;

  ThreadSupport get support => _support;

  DateTime get now => _clock();

  /// New threads are paused for every chat on this gateway.
  bool get paused => _paused;

  /// Background slots in use on the gateway, and the limit. `null` until
  /// `delegation.status` has answered.
  int? get slotsInUse => _slotsInUse;
  int? get slotLimit => _slotLimit;

  /// The model the gateway's active threads run on, when one is known.
  String? get slotModel => _slotModel;

  /// The read-only task list shown when the gateway has no thread support.
  List<GatewaySubagentActivity> get legacyActivities =>
      List.unmodifiable(_legacyActivities);

  AgentThread? thread(String id) => _threads[id];

  bool get hasThreads => _threads.isNotEmpty;

  static int _rank(AgentThreadState state) => switch (state) {
    AgentThreadState.needsYou => 0,
    AgentThreadState.running => 1,
    AgentThreadState.queued => 2,
    _ => 3,
  };

  /// Every thread: those that need the user first, then running, queued, and
  /// finished threads newest first.
  List<AgentThread> get threads {
    final sorted = _threads.values.toList();
    final order = {
      for (final (index, thread) in sorted.indexed) thread.id: index,
    };
    sorted.sort((a, b) {
      final rank = _rank(a.state).compareTo(_rank(b.state));
      if (rank != 0) return rank;
      if (a.state.isFinished) {
        final aEnd = a.endedAt, bEnd = b.endedAt;
        if (aEnd != null && bEnd != null && aEnd != bEnd) {
          return bEnd.compareTo(aEnd);
        }
        return order[b.id]!.compareTo(order[a.id]!);
      }
      return order[a.id]!.compareTo(order[b.id]!);
    });
    return sorted;
  }

  List<AgentThread> get activeThreads => [
    for (final thread in threads)
      if (thread.state.isActive) thread,
  ];

  List<AgentThread> get finishedThreads => [
    for (final thread in threads)
      if (thread.state.isFinished) thread,
  ];

  /// Threads in the order they were started, for the "Started N threads"
  /// card. Threads only known from a failure record are left out.
  List<AgentThread> get threadsInStartOrder => [
    for (final thread in _threads.values)
      if (thread.spawnedAt != null) thread,
  ];

  /// 1-based place in line of a queued follow-up, when the gateway said.
  int? queuePosition(String id) => _queuePositions[id];

  ThreadSteerRecord? steerRecord(String id) => _steers[id];

  /// Update and question messages delivered live that the stored history
  /// may not show yet.
  List<ThreadMessageAnnotation> get liveMessages =>
      List.unmodifiable(_liveMessages);

  /// How [questionId] of thread [subagentId] stands.
  ///
  /// A question this device has no record of is open only while the roster
  /// says that thread is still waiting on it.
  ThreadQuestionRecord questionRecord(String subagentId, String questionId) {
    final record = _questions[questionId];
    if (record != null) return record;
    final pending = _threads[subagentId]?.pendingQuestion;
    return ThreadQuestionRecord(
      subagentId: subagentId,
      state: pending?.questionId == questionId
          ? ThreadQuestionState.pending
          : ThreadQuestionState.closed,
    );
  }

  void _onSupportChanged() {
    final next = _gateway?.support ?? ThreadSupport.none;
    final gainedRoster = next.roster && !_support.roster;
    _support = next;
    _notify();
    // Support that arrives after the first seed attempt (a session.info
    // event) still gets its roster.
    if (gainedRoster) unawaited(seed());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Loads the roster and slot status. Called when the chat binds its
  /// gateway session and after every reconnect. Concurrent calls share one
  /// run; a failure leaves the current roster in place.
  Future<void> seed() {
    final running = _seeding;
    if (running != null) return running;
    final future = _seed();
    _seeding = future;
    return future.whenComplete(() {
      if (identical(_seeding, future)) _seeding = null;
    });
  }

  Future<void> _seed() async {
    final gateway = _gateway;
    if (gateway == null) return;
    try {
      await gateway.probe();
    } catch (_) {
      // The probe records its own verdict; a throw here is a dead socket.
    }
    _support = gateway.support;
    if (!_support.roster) {
      _notify();
      return;
    }
    try {
      final roster = await gateway.listThreads();
      if (_disposed) return;
      _mergeRoster(roster);
    } catch (_) {
      // Keep what the events built. The next bind seeds again.
    }
    await refreshStatus();
    _notify();
  }

  /// Reads the gateway-wide slot count, limit and pause flag.
  Future<void> refreshStatus() async {
    final gateway = _gateway;
    if (gateway == null || !_support.roster) return;
    try {
      final status = await gateway.delegationStatus();
      if (_disposed) return;
      _paused = status.paused;
      _slotsInUse = status.activeCount;
      _slotLimit = status.maxConcurrent;
      _slotModel = status.model;
      _notify();
    } catch (_) {
      // Slot usage is informative; the roster stands without it.
    }
  }

  void _mergeRoster(ThreadRosterSnapshot roster) {
    final now = _clock();
    final liveIds = <String>{};
    for (final row in roster.threads) {
      // Only first-level threads are the chat's threads; a thread's own
      // children stay inside it.
      if ((row.depth ?? 0) > 0) continue;
      liveIds.add(row.subagentId);
      final question = _question(row.pendingQuestion);
      final existing = _threads[row.subagentId];
      final state = question != null
          ? AgentThreadState.needsYou
          : AgentThreadState.running;
      _threads[row.subagentId] =
          (existing ??
                  AgentThread(
                    id: row.subagentId,
                    goal: row.goal ?? '',
                    state: state,
                    spawnedAt: row.startedAt ?? now,
                  ))
              .copyWith(
                goal: row.goal,
                state: state,
                delegationId: row.delegationId,
                model: row.model,
                toolCount: row.toolCount,
                startedAt: row.startedAt ?? existing?.startedAt ?? now,
                endedAt: null,
                durationSeconds: null,
                lastTool: row.lastTool,
                acceptingSteer: row.acceptingSteer,
                childSessionId: row.childSessionId,
                pendingQuestion: question,
                summary: existing?.state.isFinished == true
                    ? null
                    : existing?.summary,
                outcome: null,
              );
      _queuePositions.remove(row.subagentId);
    }

    final queuedIds = <String>{};
    for (final (index, row) in roster.queued.indexed) {
      if (liveIds.contains(row.subagentId)) continue;
      queuedIds.add(row.subagentId);
      final existing = _threads[row.subagentId];
      _threads[row.subagentId] =
          (existing ??
                  AgentThread(
                    id: row.subagentId,
                    goal: row.goal ?? '',
                    state: AgentThreadState.queued,
                    spawnedAt: row.queuedAt ?? now,
                  ))
              .copyWith(
                goal: row.goal,
                state: AgentThreadState.queued,
                pendingQuestion: null,
              );
      _queuePositions[row.subagentId] = index + 1;
    }

    // A thread this device still shows as active, but the gateway no longer
    // lists, ended while no event could arrive.
    for (final thread in _threads.values.toList()) {
      if (!thread.state.isActive ||
          liveIds.contains(thread.id) ||
          queuedIds.contains(thread.id)) {
        continue;
      }
      final failure = roster.failed
          .where((row) => row.delegationId == thread.delegationId)
          .firstOrNull;
      _threads[thread.id] = thread.copyWith(
        state: failure == null
            ? AgentThreadState.done
            : AgentThreadState.failed,
        endedAt: failure?.completedAt ?? now,
        pendingQuestion: null,
        outcome: failure?.status,
        summary: failure?.error ?? thread.summary,
      );
      _queuePositions.remove(thread.id);
      _steerMissed(thread.id);
    }

    // Recent failures of threads this device never saw run.
    for (final row in roster.failed) {
      final known = _threads.values.any(
        (thread) =>
            thread.delegationId == row.delegationId &&
            !thread.id.startsWith('failed:'),
      );
      if (known) continue;
      final id = 'failed:${row.delegationId}:${row.taskIndex}';
      _threads[id] = AgentThread(
        id: id,
        goal: row.goal ?? '',
        state: ThreadOutcome.stopped(row.status)
            ? AgentThreadState.stopped
            : AgentThreadState.failed,
        delegationId: row.delegationId,
        endedAt: row.completedAt,
        summary: row.error,
        outcome: row.status,
      );
    }

    // Question events are live-only. After a reconnect the roster is the
    // truth: a question no thread still waits on is closed.
    for (final entry in _questions.entries.toList()) {
      if (!entry.value.isOpen) continue;
      final pending = _threads[entry.value.subagentId]?.pendingQuestion;
      if (pending?.questionId != entry.key) {
        _questions[entry.key] = ThreadQuestionRecord(
          subagentId: entry.value.subagentId,
          state: ThreadQuestionState.closed,
        );
      }
    }
  }

  static AgentThreadQuestion? _question(ThreadQuestionWire? wire) =>
      wire == null
      ? null
      : AgentThreadQuestion(
          questionId: wire.questionId,
          text: wire.text,
          options: wire.options,
          askedAt: wire.askedAt,
          expiresAt: wire.expiresAt,
        );

  /// Applies one gateway event. Returns whether it was a thread event.
  bool applyEvent(String type, Map<String, dynamic> data) {
    if (!type.startsWith('subagent.')) return false;
    if (type == ThreadEventType.question) {
      final event = ThreadQuestionEvent.parse(data);
      if (event != null) _applyQuestion(event);
      return true;
    }
    if (type == ThreadEventType.message) {
      final message = ThreadMessageAnnotation.parse(data);
      if (message != null) _applyMessage(message);
      return true;
    }

    final legacy = GatewaySubagentActivity.fromGatewayEvent(type, data);
    if (legacy != null) {
      final index = _legacyActivities.indexWhere(
        (activity) => activity.id == legacy.id,
      );
      if (index < 0) {
        _legacyActivities.add(legacy);
      } else {
        _legacyActivities[index] = _legacyActivities[index].merge(legacy);
      }
    }

    final event = ThreadProgressEvent.parse(type, data);
    if (event != null && (event.depth ?? 0) == 0) _applyProgress(event);
    _notify();
    return true;
  }

  void _applyProgress(ThreadProgressEvent event) {
    final now = _clock();
    final existing = _threads[event.subagentId];
    final starts =
        event.type == ThreadEventType.spawnRequested ||
        event.type == ThreadEventType.start;

    if (event.isComplete) {
      final state = ThreadOutcome.succeeded(event.status)
          ? AgentThreadState.done
          : ThreadOutcome.stopped(event.status)
          ? AgentThreadState.stopped
          : AgentThreadState.failed;
      final finished =
          (existing ??
                  AgentThread(
                    id: event.subagentId,
                    goal: event.goal ?? '',
                    state: state,
                    spawnedAt: now,
                    startedAt: now,
                  ))
              .copyWith(
                goal: event.goal,
                // A stop the user asked for stays a stop, whatever status
                // the interrupted run reports.
                state: existing?.state == AgentThreadState.stopped
                    ? AgentThreadState.stopped
                    : state,
                model: event.model,
                delegationId: event.delegationId,
                childSessionId: event.childSessionId,
                toolCount: event.toolCount,
                endedAt: now,
                durationSeconds: event.durationSeconds,
                pendingQuestion: null,
                summary: event.summary ?? existing?.summary,
                outcome: event.status,
              );
      _threads[event.subagentId] = finished;
      _queuePositions.remove(event.subagentId);
      _steerMissed(event.subagentId);
      _closeQuestionsOf(event.subagentId, ThreadQuestionState.cancelled);
      if (existing == null || existing.state.isActive) {
        onThreadFinished?.call(finished);
      }
      return;
    }

    if (existing != null && existing.state.isFinished && !starts) {
      // A progress event that arrives after the completion it belongs to.
      return;
    }
    final restarts = existing != null && !existing.state.isLive && starts;
    final base =
        existing ??
        AgentThread(
          id: event.subagentId,
          goal: event.goal ?? '',
          state: AgentThreadState.running,
          spawnedAt: now,
          startedAt: now,
        );
    final isTool = event.type == ThreadEventType.tool;
    _threads[event.subagentId] = base.copyWith(
      goal: event.goal,
      state: base.state == AgentThreadState.needsYou && !restarts
          ? AgentThreadState.needsYou
          : AgentThreadState.running,
      model: event.model,
      delegationId: event.delegationId,
      childSessionId: event.childSessionId,
      toolCount:
          event.toolCount ??
          (restarts
              ? 0
              : isTool
              ? base.toolCount + 1
              : null),
      startedAt: restarts ? now : null,
      endedAt: restarts ? null : base.endedAt,
      durationSeconds: restarts ? null : base.durationSeconds,
      lastTool: isTool ? event.toolName : null,
      summary: restarts ? null : base.summary,
      outcome: restarts ? null : base.outcome,
    );
    if (restarts) _queuePositions.remove(event.subagentId);

    // Any step after a queued steer is the thread picking it up.
    final steer = _steers[event.subagentId];
    if (!starts && steer?.status == ThreadSteerStatus.sent) {
      _steers[event.subagentId] = ThreadSteerRecord(
        text: steer!.text,
        status: ThreadSteerStatus.acknowledged,
      );
    }
  }

  void _steerMissed(String id) {
    final steer = _steers[id];
    if (steer == null) return;
    if (steer.status == ThreadSteerStatus.sent ||
        steer.status == ThreadSteerStatus.sending) {
      _steers[id] = ThreadSteerRecord(
        text: steer.text,
        status: ThreadSteerStatus.didNotLand,
      );
    }
  }

  void _closeQuestionsOf(String subagentId, ThreadQuestionState state) {
    for (final entry in _questions.entries.toList()) {
      if (entry.value.subagentId == subagentId && entry.value.isOpen) {
        _questions[entry.key] = ThreadQuestionRecord(
          subagentId: subagentId,
          state: state,
        );
      }
    }
  }

  void _applyQuestion(ThreadQuestionEvent event) {
    final existing = _threads[event.subagentId];
    switch (event.status) {
      case ThreadQuestionStatus.pending:
        final question =
            _question(event.question) ??
            AgentThreadQuestion(questionId: event.questionId, text: '');
        _questions[event.questionId] = ThreadQuestionRecord(
          subagentId: event.subagentId,
          state: ThreadQuestionState.pending,
        );
        if (existing == null || existing.state.isLive) {
          final now = _clock();
          final thread =
              (existing ??
                      AgentThread(
                        id: event.subagentId,
                        goal: event.goal ?? '',
                        state: AgentThreadState.needsYou,
                        spawnedAt: now,
                        startedAt: now,
                      ))
                  .copyWith(
                    goal: event.goal,
                    state: AgentThreadState.needsYou,
                    pendingQuestion: question,
                  );
          _threads[event.subagentId] = thread;
          onThreadQuestion?.call(thread, question);
        }
      case ThreadQuestionStatus.answered:
        _questions[event.questionId] = ThreadQuestionRecord(
          subagentId: event.subagentId,
          state: ThreadQuestionState.answered,
          answer: event.answer ?? _questions[event.questionId]?.answer,
          answeredBy: event.answeredBy,
        );
        _resume(existing, event.questionId);
      case ThreadQuestionStatus.expired:
      case ThreadQuestionStatus.cancelled:
        _questions[event.questionId] = ThreadQuestionRecord(
          subagentId: event.subagentId,
          state: event.status == ThreadQuestionStatus.expired
              ? ThreadQuestionState.expired
              : ThreadQuestionState.cancelled,
        );
        _resume(existing, event.questionId);
    }
    _notify();
  }

  /// The thread stops waiting on [questionId] and runs again.
  void _resume(AgentThread? thread, String questionId) {
    if (thread == null || thread.pendingQuestion?.questionId != questionId) {
      return;
    }
    _threads[thread.id] = thread.copyWith(
      state: thread.state == AgentThreadState.needsYou
          ? AgentThreadState.running
          : thread.state,
      pendingQuestion: null,
    );
  }

  void _applyMessage(ThreadMessageAnnotation message) {
    if (_liveMessages.any((item) => item.messageId == message.messageId)) {
      return;
    }
    _liveMessages.add(message);
    if (_liveMessages.length > 50) _liveMessages.removeAt(0);
    final questionId = message.questionId;
    if (message.isQuestion &&
        questionId != null &&
        !_questions.containsKey(questionId)) {
      // The lifecycle event normally arrives first. Without it, the roster
      // decides whether the thread is still waiting.
      final thread = _threads[message.subagentId];
      if (thread != null &&
          thread.state.isLive &&
          thread.pendingQuestion == null) {
        final question = AgentThreadQuestion(
          questionId: questionId,
          text: message.text,
          options: message.options,
          askedAt: message.sentAt,
          expiresAt: message.expiresAt,
        );
        _threads[thread.id] = thread.copyWith(
          state: AgentThreadState.needsYou,
          pendingQuestion: question,
        );
        _questions[questionId] = ThreadQuestionRecord(
          subagentId: message.subagentId,
          state: ThreadQuestionState.pending,
        );
      }
    }
    _notify();
  }

  // ── Actions ────────────────────────────────────────────────────────────

  /// Interrupts one thread. Returns whether the gateway found it running.
  Future<bool> stop(String id) async {
    final gateway = _gateway;
    if (gateway == null) return false;
    final result = await gateway.interrupt(id);
    final thread = _threads[id];
    if (result.found && thread != null && thread.state.isActive) {
      _threads[id] = thread.copyWith(
        state: AgentThreadState.stopped,
        endedAt: _clock(),
        pendingQuestion: null,
      );
      _steerMissed(id);
      _closeQuestionsOf(id, ThreadQuestionState.cancelled);
      _notify();
    } else if (!result.found) {
      // It had already ended; the roster says how.
      unawaited(seed());
    }
    return result.found;
  }

  /// Interrupts every running thread of this chat. Returns how many the
  /// gateway confirmed.
  Future<int> stopAll() async {
    var stopped = 0;
    for (final thread in activeThreads) {
      if (!thread.state.isLive) continue;
      try {
        if (await stop(thread.id)) stopped += 1;
      } catch (_) {
        // One refusal does not keep the others running.
      }
    }
    unawaited(refreshStatus());
    return stopped;
  }

  /// Pauses or resumes new threads for the whole gateway.
  Future<void> setPaused(bool paused) async {
    final gateway = _gateway;
    if (gateway == null) return;
    _paused = await gateway.setPaused(paused);
    _notify();
  }

  /// The last part of a running thread's live transcript.
  Future<ThreadTailSnapshot> tail(String id) {
    final gateway = _gateway;
    if (gateway == null) {
      return Future.value(const ThreadTailSnapshot(available: false));
    }
    return gateway.tail(id);
  }

  /// Sends steer text to one thread. The returned record, also readable
  /// through [steerRecord], says whether the gateway queued it.
  Future<ThreadSteerRecord> steer(String id, String text) async {
    final gateway = _gateway;
    final trimmed = text.trim();
    if (gateway == null || trimmed.isEmpty) {
      return ThreadSteerRecord(
        text: trimmed,
        status: ThreadSteerStatus.didNotLand,
      );
    }
    _steers[id] = ThreadSteerRecord(
      text: trimmed,
      status: ThreadSteerStatus.sending,
    );
    _notify();
    ThreadSteerStatus status;
    try {
      final result = await gateway.steer(id, trimmed);
      status = result.queued
          ? ThreadSteerStatus.sent
          : ThreadSteerStatus.didNotLand;
    } catch (_) {
      _steers.remove(id);
      _notify();
      rethrow;
    }
    // The thread may have finished while the call was in flight.
    if (status == ThreadSteerStatus.sent &&
        _threads[id]?.state.isLive == false) {
      status = ThreadSteerStatus.didNotLand;
    }
    final record = ThreadSteerRecord(text: trimmed, status: status);
    _steers[id] = record;
    _notify();
    return record;
  }

  /// Forgets the steer outcome shown for a thread.
  void clearSteer(String id) {
    if (_steers.remove(id) != null) _notify();
  }

  /// Answers a thread question as the user.
  ///
  /// Throws [ThreadQuestionClosedException] when the gateway says the
  /// question is no longer open; the record is then marked closed.
  Future<void> reply({
    required String subagentId,
    required String questionId,
    required String text,
  }) async {
    final gateway = _gateway;
    if (gateway == null) {
      throw StateError('The gateway is not connected');
    }
    try {
      await gateway.reply(
        subagentId: subagentId,
        questionId: questionId,
        text: text,
      );
    } on JsonRpcError catch (error) {
      if (error.code != ThreadReplyWire.closedCode) rethrow;
      final current = _questions[questionId];
      if (current == null || current.isOpen) {
        _questions[questionId] = ThreadQuestionRecord(
          subagentId: subagentId,
          state: ThreadQuestionState.closed,
        );
      }
      _resume(_threads[subagentId], questionId);
      _notify();
      throw ThreadQuestionClosedException(error.message);
    }
    final current = _questions[questionId];
    if (current?.state != ThreadQuestionState.answered) {
      _questions[questionId] = ThreadQuestionRecord(
        subagentId: subagentId,
        state: ThreadQuestionState.answered,
        answer: text,
        answeredBy: ThreadAnsweredBy.user,
      );
    }
    _resume(_threads[subagentId], questionId);
    _notify();
  }

  /// Records that the coordinator was asked to answer. The answer arrives
  /// as a `subagent.question` event.
  void markCoordinatorDeciding({
    required String subagentId,
    required String questionId,
  }) {
    final current = questionRecord(subagentId, questionId);
    if (current.state != ThreadQuestionState.pending) return;
    _questions[questionId] = ThreadQuestionRecord(
      subagentId: subagentId,
      state: ThreadQuestionState.deciding,
    );
    _notify();
  }

  /// The coordinator prompt could not be sent: the question is open again.
  void clearCoordinatorDeciding(String questionId) {
    final current = _questions[questionId];
    if (current?.state != ThreadQuestionState.deciding) return;
    _questions[questionId] = ThreadQuestionRecord(
      subagentId: current!.subagentId,
      state: ThreadQuestionState.pending,
    );
    _notify();
  }

  /// Sends a follow-up to a finished thread.
  Future<ThreadContinueResult> continueThread(String id, String text) async {
    final gateway = _gateway;
    if (gateway == null) {
      throw StateError('The gateway is not connected');
    }
    final result = await gateway.continueThread(id, text.trim());
    final now = _clock();
    final thread =
        _threads[id] ??
        AgentThread(
          id: id,
          goal: '',
          state: AgentThreadState.queued,
          spawnedAt: now,
        );
    switch (result.status) {
      case ThreadContinueStatus.dispatched:
        _threads[id] = thread.copyWith(
          state: AgentThreadState.running,
          delegationId: result.delegationId,
          childSessionId: result.childSessionId,
          toolCount: 0,
          startedAt: now,
          endedAt: null,
          durationSeconds: null,
          summary: null,
          outcome: null,
        );
        _queuePositions.remove(id);
      case ThreadContinueStatus.queued:
        _threads[id] = thread.copyWith(state: AgentThreadState.queued);
        if (result.position case final position?) {
          _queuePositions[id] = position;
        }
      case ThreadContinueStatus.rejected:
        break;
    }
    _notify();
    unawaited(refreshStatus());
    return result;
  }

  /// Makes a finished thread known by what its report card says, so the
  /// card can open it. A thread the roster already has is left as it is.
  void rememberFinished({
    required String id,
    String? goal,
    String? status,
    int? toolCount,
    double? durationSeconds,
    String? summary,
  }) {
    if (_threads.containsKey(id)) return;
    _threads[id] = AgentThread(
      id: id,
      goal: goal ?? '',
      state: ThreadOutcome.succeeded(status)
          ? AgentThreadState.done
          : ThreadOutcome.stopped(status)
          ? AgentThreadState.stopped
          : AgentThreadState.failed,
      toolCount: toolCount ?? 0,
      durationSeconds: durationSeconds,
      summary: summary,
      outcome: status,
    );
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _gateway?.supportChanges?.removeListener(_onSupportChanged);
    super.dispose();
  }
}
