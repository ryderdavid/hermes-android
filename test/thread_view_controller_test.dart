import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/agent_thread.dart';
import 'package:hermes_android/core/services/agent_threads_controller.dart';
import 'package:hermes_android/core/services/thread_view_controller.dart';
import 'package:hermes_android/core/services/thread_wire.dart';
import 'package:hermes_android/core/utils/chat_display_items.dart';

import 'support/fake_threads_gateway.dart';

const _tail = '''
14:32:01 user     | kickoff: List every runtime dependency with its licence.
14:32:05 tool     | -> terminal({"command": "flutter pub deps --json"})
14:32:08 result   | terminal ok 3.1s: {}
14:32:09 tool     | -> read_file({"path": "pubspec.lock"})
''';

Map<String, dynamic> _event(String id, [Map<String, dynamic>? more]) => {
  'subagent_id': id,
  'goal': 'Audit dependency licences',
  'child_session_id': 'child-a',
  ...?more,
};

/// A stored child transcript: the task, one tool call, the final answer.
List<Map<String, dynamic>> _stored({int tools = 1}) => [
  {'id': 1, 'role': 'user', 'content': 'List every runtime dependency.'},
  for (var index = 0; index < tools; index++)
    {
      'id': 2 + index,
      'role': 'tool',
      'tool_name': 'terminal',
      'tool_call_id': 'call-$index',
      'content': 'ok',
    },
  {'id': 900, 'role': 'assistant', 'content': '41 of 48 are permissive.'},
];

class _History {
  final Map<String, List<Map<String, dynamic>>> sessions = {};
  final List<(String, int, int)> reads = [];

  /// Offsets whose page read fails.
  final Set<int> failingOffsets = {};

  Future<List<Map<String, dynamic>>> load(
    String sessionId, {
    required int limit,
    required int offset,
  }) async {
    reads.add((sessionId, limit, offset));
    if (failingOffsets.contains(offset)) throw StateError('HTTP 500');
    final rows = sessions[sessionId];
    if (rows == null) throw StateError('HTTP 404');
    final end = (rows.length - offset).clamp(0, rows.length);
    final start = (end - limit).clamp(0, end);
    return rows.sublist(start, end);
  }
}

({
  FakeThreadsGateway gateway,
  AgentThreadsController threads,
  ThreadViewController view,
  _History history,
})
_setUp({bool running = true, int pageSize = 200, int maxPages = 5}) {
  final gateway = FakeThreadsGateway(support: ThreadSupport.full)
    ..tailSnapshot = const ThreadTailSnapshot(available: true, text: _tail);
  final threads = AgentThreadsController(gateway: gateway);
  addTearDown(threads.dispose);
  threads.applyEvent(ThreadEventType.start, _event('a'));
  if (!running) {
    threads.applyEvent(
      ThreadEventType.complete,
      _event('a', {'status': 'completed'}),
    );
  }
  final history = _History();
  final view = ThreadViewController(
    threads: threads,
    threadId: 'a',
    loadHistory: history.load,
    pageSize: pageSize,
    maxPages: maxPages,
  );
  addTearDown(view.dispose);
  return (gateway: gateway, threads: threads, view: view, history: history);
}

void main() {
  group('live tail', () {
    testWidgets('nothing is polled until the view is visible', (tester) async {
      final s = _setUp();

      await tester.pump(const Duration(seconds: 5));

      expect(s.gateway.callCount('tail'), 0);
      expect(s.view.isPolling, isFalse);
    });

    testWidgets('polls at once, then every two seconds while visible', (
      tester,
    ) async {
      final s = _setUp();

      s.view.setVisible(true);
      await tester.pump();
      expect(s.gateway.calls, ['tail a']);
      expect(s.view.isPolling, isTrue);

      await tester.pump(const Duration(milliseconds: 1900));
      expect(s.gateway.callCount('tail'), 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(s.gateway.callCount('tail'), 2);
      await tester.pump(const Duration(seconds: 2));
      expect(s.gateway.callCount('tail'), 3);

      s.view.setVisible(false);
    });

    testWidgets('stops when the view is hidden and resumes when shown', (
      tester,
    ) async {
      final s = _setUp();
      s.view.setVisible(true);
      await tester.pump();

      s.view.setVisible(false);
      await tester.pump(const Duration(seconds: 10));
      expect(s.gateway.callCount('tail'), 1);
      expect(s.view.isPolling, isFalse);

      s.view.setVisible(true);
      await tester.pump();
      expect(s.gateway.callCount('tail'), 2);

      s.view.setVisible(false);
    });

    testWidgets('the tail becomes the same rows the chat draws', (
      tester,
    ) async {
      final s = _setUp();
      s.view.setVisible(true);
      await tester.pump();

      expect(s.view.task, 'List every runtime dependency with its licence.');
      final steps = s.view.transcript
          .displayItems(running: true)
          .whereType<ChatActivityStep>()
          .toList();
      expect(steps.map((step) => step.activity!.name), [
        'terminal',
        'read_file',
      ]);
      expect(steps.first.isRunning, isFalse);
      expect(steps.first.activity!.durationSeconds, 3.1);
      expect(steps.last.isRunning, isTrue);
      expect(steps.last.activity!.summary, 'pubspec.lock');

      s.view.setVisible(false);
    });

    testWidgets('a thread event polls without waiting for the tick', (
      tester,
    ) async {
      final s = _setUp();
      s.view.setVisible(true);
      await tester.pump();
      expect(s.gateway.callCount('tail'), 1);

      s.threads.applyEvent(
        ThreadEventType.tool,
        _event('a', {'tool_name': 'web_search'}),
      );
      await tester.pump();

      expect(s.gateway.callCount('tail'), 2);
      s.view.setVisible(false);
    });

    testWidgets('a tail that is not available yet keeps what was shown', (
      tester,
    ) async {
      final s = _setUp();
      s.view.setVisible(true);
      await tester.pump();
      s.gateway.tailSnapshot = const ThreadTailSnapshot(available: false);

      await tester.pump(const Duration(seconds: 2));

      expect(s.view.transcript.activities, hasLength(2));
      s.view.setVisible(false);
    });

    testWidgets('says when the tail no longer reaches the first steps', (
      tester,
    ) async {
      final s = _setUp();
      s.gateway.tailSnapshot = const ThreadTailSnapshot(
        available: true,
        text: '14:40:00 tool     | -> terminal({"command": "ls"})\n',
        truncated: true,
      );
      s.view.setVisible(true);
      await tester.pump();

      expect(s.view.tailTruncated, isTrue);
      // The kickoff line scrolled out; the roster's goal stands in.
      expect(s.view.task, 'Audit dependency licences');
      s.view.setVisible(false);
    });
  });

  group('hand-over to stored history', () {
    testWidgets('on completion polling stops and the transcript is read', (
      tester,
    ) async {
      final s = _setUp();
      s.history.sessions['child-a'] = _stored();
      s.view.setVisible(true);
      await tester.pump();
      expect(s.view.historyStatus, ThreadHistoryStatus.idle);

      s.threads.applyEvent(
        ThreadEventType.complete,
        _event('a', {'status': 'completed'}),
      );
      await tester.pump();
      await tester.pump();

      expect(s.view.isPolling, isFalse);
      expect(s.view.isLive, isFalse);
      expect(s.history.reads, [('child-a', 200, 0)]);
      expect(s.view.historyStatus, ThreadHistoryStatus.loaded);
      expect(s.view.task, 'List every runtime dependency.');
      final items = s.view.transcript.displayItems(running: false);
      // A finished transcript is unfolded: the view exists to show the work.
      expect(items.whereType<ChatTurnFold>().single.unfolded, isTrue);
      expect(items.whereType<ChatActivityStep>(), hasLength(1));

      final polls = s.gateway.callCount('tail');
      await tester.pump(const Duration(seconds: 6));
      expect(s.gateway.callCount('tail'), polls);
    });

    testWidgets('a thread opened after it finished reads history, no tail', (
      tester,
    ) async {
      final s = _setUp(running: false);
      s.history.sessions['child-a'] = _stored();

      s.view.setVisible(true);
      await tester.pump();
      await tester.pump();

      expect(s.gateway.callCount('tail'), 0);
      expect(s.view.historyStatus, ThreadHistoryStatus.loaded);
    });

    testWidgets('history that cannot be read at all is marked unavailable, '
        'and the last tail stays', (tester) async {
      final s = _setUp();
      s.view.setVisible(true);
      await tester.pump();

      // No stored session for child-a: the read fails.
      s.threads.applyEvent(
        ThreadEventType.complete,
        _event('a', {'status': 'completed'}),
      );
      await tester.pump();
      await tester.pump();

      expect(s.view.historyStatus, ThreadHistoryStatus.unavailable);
      expect(s.view.transcript.activities, hasLength(2));
    });

    testWidgets('a thread with no stored session is unavailable, not an '
        'error', (tester) async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full);
      final threads = AgentThreadsController(gateway: gateway);
      addTearDown(threads.dispose);
      threads.rememberFinished(id: 'old', goal: 'Draft release notes');
      final history = _History();
      final view = ThreadViewController(
        threads: threads,
        threadId: 'old',
        loadHistory: history.load,
      );
      addTearDown(view.dispose);

      view.setVisible(true);
      await tester.pump();

      expect(view.historyStatus, ThreadHistoryStatus.unavailable);
      expect(history.reads, isEmpty);
      expect(view.task, 'Draft release notes');
    });

    testWidgets('a failed older page leaves a partial transcript, labelled', (
      tester,
    ) async {
      final s = _setUp(running: false, pageSize: 3);
      s.history.sessions['child-a'] = _stored(tools: 6);
      s.history.failingOffsets.add(3);

      s.view.setVisible(true);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(s.history.reads, [('child-a', 3, 0), ('child-a', 3, 3)]);
      expect(s.view.historyStatus, ThreadHistoryStatus.partial);
      // What could be loaded is shown: the newest page.
      final items = s.view.transcript.displayItems(running: false);
      expect(
        items.whereType<Map<String, dynamic>>().last['_display_content'],
        '41 of 48 are permissive.',
      );
    });

    testWidgets('a transcript longer than the page budget is partial', (
      tester,
    ) async {
      final s = _setUp(running: false, pageSize: 2, maxPages: 2);
      s.history.sessions['child-a'] = _stored(tools: 10);

      s.view.setVisible(true);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(s.history.reads, hasLength(2));
      expect(s.view.historyStatus, ThreadHistoryStatus.partial);
    });

    testWidgets('retry reads the history again', (tester) async {
      final s = _setUp(running: false);
      s.view.setVisible(true);
      await tester.pump();
      await tester.pump();
      expect(s.view.historyStatus, ThreadHistoryStatus.unavailable);

      s.history.sessions['child-a'] = _stored();
      await s.view.retryHistory();

      expect(s.view.historyStatus, ThreadHistoryStatus.loaded);
    });

    testWidgets('a continued thread goes back to the live tail', (
      tester,
    ) async {
      final s = _setUp(running: false);
      s.history.sessions['child-a'] = _stored();
      s.view.setVisible(true);
      await tester.pump();
      await tester.pump();
      expect(s.view.historyStatus, ThreadHistoryStatus.loaded);

      s.threads.applyEvent(ThreadEventType.start, _event('a'));
      await tester.pump();

      expect(s.view.isPolling, isTrue);
      expect(s.view.historyStatus, ThreadHistoryStatus.idle);
      expect(s.threads.thread('a')!.state, AgentThreadState.running);
      s.view.setVisible(false);
    });
  });
}
