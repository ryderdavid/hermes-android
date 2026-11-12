import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/agent_thread.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/screens/thread_screen.dart';
import 'package:hermes_android/core/services/agent_threads_controller.dart';
import 'package:hermes_android/core/services/thread_wire.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/core/widgets/activity_detail_sheet.dart';
import 'package:hermes_android/core/widgets/activity_row.dart';
import 'package:hermes_android/core/widgets/chat_composer.dart';
import 'package:hermes_android/core/widgets/thread_steer_bar.dart';
import 'package:hermes_android/core/widgets/turn_fold.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_threads_gateway.dart';
import 'support/thread_chat_harness.dart';

final _now = DateTime.utc(2026, 11, 11, 14, 34);

const _tail = '''
14:32:01 user     | kickoff: List every runtime dependency with its licence.
14:32:05 tool     | -> terminal({"command": "flutter pub deps --json"})
14:32:08 result   | terminal ok 3.1s: {}
14:32:20 assistant| 41 of 48 runtime packages are MIT/BSD/Apache.
14:32:21 tool     | -> read_file({"path": "pubspec.lock"})
''';

List<Map<String, dynamic>> _stored() => [
  {'id': 1, 'role': 'user', 'content': 'List every runtime dependency.'},
  {
    'id': 2,
    'role': 'tool',
    'tool_name': 'terminal',
    'tool_call_id': 'c1',
    'content': 'ok',
  },
  {'id': 3, 'role': 'assistant', 'content': 'All 48 are permissive.'},
];

class _Screen {
  _Screen(this.gateway, this.threads);
  final FakeThreadsGateway gateway;
  final AgentThreadsController threads;
  final Map<String, List<Map<String, dynamic>>> history = {};
  bool historyFails = false;

  Future<List<Map<String, dynamic>>> load(
    String sessionId, {
    required int limit,
    required int offset,
  }) async {
    if (historyFails) throw StateError('HTTP 500');
    final rows = history[sessionId];
    if (rows == null) throw StateError('HTTP 404');
    return offset == 0 ? rows : const [];
  }

  void event(String type, [Map<String, dynamic>? more]) =>
      threads.applyEvent(type, {
        'subagent_id': 'a',
        'goal': 'Audit dependency licences',
        'child_session_id': 'child-a',
        ...?more,
      });
}

Future<_Screen> _pump(
  WidgetTester tester, {
  ThreadSupport support = ThreadSupport.full,
  bool finished = false,
  bool? acceptingSteer,
}) async {
  final gateway = FakeThreadsGateway(support: support)
    ..tailSnapshot = const ThreadTailSnapshot(available: true, text: _tail)
    ..roster = ThreadRosterSnapshot(
      threads: [
        rosterRow(
          'a',
          goal: 'Audit dependency licences',
          tools: 7,
          model: 'claude-sonnet-5-5',
          startedAt: _now.millisecondsSinceEpoch / 1000 - 120,
          childSessionId: 'child-a',
          acceptingSteer: acceptingSteer,
        ),
      ],
    );
  final threads = AgentThreadsController(gateway: gateway, clock: () => _now);
  addTearDown(threads.dispose);
  await threads.seed();
  final screen = _Screen(gateway, threads);
  if (finished) {
    screen.history['child-a'] = _stored();
    screen.event(ThreadEventType.complete, {
      'status': 'completed',
      'tool_count': 9,
      'duration_seconds': 150.0,
    });
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: hermesTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThreadScreen(
        threads: threads,
        threadId: 'a',
        chatTitle: 'Release 3.2 planning',
        loadHistory: screen.load,
      ),
    ),
  );
  await threadFrames(tester);
  // The screen's poll timer must be gone before the test ends.
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  return screen;
}

String _status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('thread-steer-status'))).data!;

void main() {
  group('running thread', () {
    testWidgets('shows the task, state, tools, time, model and a live '
        'indicator', (tester) async {
      await _pump(tester);

      expect(find.text('Audit dependency licences'), findsOneWidget);
      expect(find.text('Thread of Release 3.2 planning'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('thread-meta'))).data,
        'Running · 7 tools · 2m 0s · claude-sonnet-5-5',
      );
      expect(find.byKey(const Key('thread-live')), findsOneWidget);
      expect(find.text('Task from the coordinator'), findsOneWidget);
      expect(
        find.text('List every runtime dependency with its licence.'),
        findsOneWidget,
      );
    });

    testWidgets('draws tool activity and text with the chat\'s own rows', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(ActivityRow), findsNWidgets(2));
      expect(find.text('Read file: pubspec.lock'), findsOneWidget);
      final bubble = tester.widget<MessageBubble>(find.byType(MessageBubble));
      expect(bubble.content, '41 of 48 runtime packages are MIT/BSD/Apache.');
      expect(bubble.isUser, isFalse);
      // Read-only: the steer bar is not the chat composer.
      expect(find.byType(ChatComposer), findsNothing);
      // The task is a card, not a user bubble.
      expect(
        tester
            .widgetList<MessageBubble>(find.byType(MessageBubble))
            .where((b) => b.isUser),
        isEmpty,
      );
    });

    testWidgets('new activity appears as the thread works', (tester) async {
      final screen = await _pump(tester);
      expect(find.text('Web search: pdfx_core licence'), findsNothing);

      screen.gateway.tailSnapshot = const ThreadTailSnapshot(
        available: true,
        text:
            '$_tail'
            '14:32:22 result   | read_file ok 0.2s: sdks\n'
            '14:32:30 tool     | -> web_search({"query": "pdfx_core licence"})\n',
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.byType(ActivityRow), findsNWidgets(3));
      expect(find.text('Web search: pdfx_core licence'), findsOneWidget);
    });

    testWidgets('a row opens the same detail sheet as in the chat', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Read file: pubspec.lock'));
      await threadFrames(tester);

      expect(find.byType(ActivityDetailSheet), findsOneWidget);
    });
  });

  group('finished thread', () {
    testWidgets('shows the stored transcript, marked done, with no live '
        'indicator', (tester) async {
      await _pump(tester, finished: true);

      expect(
        tester.widget<Text>(find.byKey(const Key('thread-meta'))).data,
        'Done · 9 tools · 2m 30s · claude-sonnet-5-5',
      );
      expect(find.byKey(const Key('thread-live')), findsNothing);
      expect(find.text('List every runtime dependency.'), findsOneWidget);
      expect(find.byType(TurnFoldLine), findsOneWidget);
      expect(find.byType(ActivityRow), findsOneWidget);
      expect(
        tester.widget<MessageBubble>(find.byType(MessageBubble)).content,
        'All 48 are permissive.',
      );
      expect(find.byKey(const Key('thread-history-unavailable')), findsNothing);
    });

    testWidgets('a failed thread is marked failed', (tester) async {
      final screen = await _pump(tester);
      screen.history['child-a'] = _stored();

      screen.event(ThreadEventType.complete, {'status': 'error'});
      await threadFrames(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('thread-meta'))).data,
        startsWith('Failed'),
      );
      expect(find.byKey(const Key('thread-live')), findsNothing);
    });

    testWidgets('history that cannot be loaded is labelled; what was shown '
        'stays', (tester) async {
      final screen = await _pump(tester);
      screen.historyFails = true;

      screen.event(ThreadEventType.complete, {'status': 'completed'});
      await threadFrames(tester);

      expect(
        find.byKey(const Key('thread-history-unavailable')),
        findsOneWidget,
      );
      expect(
        find.text('The stored transcript could not be loaded.'),
        findsOneWidget,
      );
      // Not an error screen: the task and the last live activity remain.
      expect(find.text('Task from the coordinator'), findsOneWidget);
      expect(find.byType(ActivityRow), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      // Retry once the gateway answers.
      screen
        ..historyFails = false
        ..history['child-a'] = _stored();
      await tester.tap(find.text('Retry'));
      await threadFrames(tester);
      expect(find.byKey(const Key('thread-history-unavailable')), findsNothing);
      expect(find.text('All 48 are permissive.'), findsOneWidget);
    });
  });

  group('steer bar', () {
    Future<void> steer(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const Key('thread-steer-field')), text);
      await tester.pump();
      await tester.tap(find.byKey(const Key('thread-steer-send')));
      await threadFrames(tester);
    }

    TextField field(WidgetTester tester) =>
        tester.widget<TextField>(find.byKey(const Key('thread-steer-field')));

    testWidgets('sends the text to that thread and records it as queued, '
        'then acknowledged', (tester) async {
      final screen = await _pump(tester);

      await steer(tester, 'Skip dev-only dependencies');

      expect(
        screen.gateway.calls,
        contains('steer a|Skip dev-only dependencies'),
      );
      expect(_status(tester), "Steer queued for the thread's next step.");
      expect(field(tester).controller!.text, isEmpty);

      screen.event(ThreadEventType.tool, {'tool_name': 'terminal'});
      await threadFrames(tester);
      expect(_status(tester), 'The thread picked up your steer.');
    });

    testWidgets('a steer that races with completion did not land; the text '
        'is kept for a follow-up', (tester) async {
      final screen = await _pump(tester);
      screen.history['child-a'] = _stored();
      await steer(tester, 'Skip dev-only dependencies');

      screen.event(ThreadEventType.complete, {'status': 'completed'});
      await threadFrames(tester);

      expect(
        _status(tester),
        startsWith('The thread finished before your steer'),
      );
      expect(field(tester).controller!.text, 'Skip dev-only dependencies');
      // The gateway continues threads: the kept text can go as a follow-up.
      expect(find.byKey(const Key('thread-continue-send')), findsOneWidget);
      await tester.tap(find.byKey(const Key('thread-continue-send')));
      await threadFrames(tester);
      expect(
        screen.gateway.calls,
        contains('continue a|Skip dev-only dependencies'),
      );
    });

    testWidgets('a steer the gateway rejects stays in the field', (
      tester,
    ) async {
      final screen = await _pump(tester);
      screen.gateway.steerResult = const ThreadSteerResult(queued: false);

      await steer(tester, 'Too late');

      expect(
        _status(tester),
        startsWith('The thread finished before your steer'),
      );
      expect(field(tester).controller!.text, 'Too late');
    });

    testWidgets('a transport failure is reported and the text kept', (
      tester,
    ) async {
      final screen = await _pump(tester);
      screen.gateway.failures['steer'] = StateError('socket closed');

      await steer(tester, 'Skip dev-only dependencies');

      expect(_status(tester), startsWith("Couldn't send the steer"));
      expect(field(tester).controller!.text, 'Skip dev-only dependencies');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stop interrupts that thread', (tester) async {
      final screen = await _pump(tester);
      screen.history['child-a'] = _stored();

      await tester.tap(find.byKey(const Key('thread-stop')));
      await threadFrames(tester);

      expect(screen.gateway.calls, contains('interrupt a'));
      expect(screen.threads.thread('a')!.state, AgentThreadState.stopped);
      expect(find.byKey(const Key('thread-live')), findsNothing);
      expect(find.byKey(const Key('thread-stop')), findsNothing);
    });

    testWidgets('a thread that does not accept steering: input disabled '
        'with the reason, Stop still there', (tester) async {
      final screen = await _pump(tester, acceptingSteer: false);

      expect(field(tester).enabled, isFalse);
      expect(_status(tester), "This thread doesn't accept steering.");
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('thread-steer-send')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('thread-stop')));
      await threadFrames(tester);
      expect(screen.gateway.calls, contains('interrupt a'));
    });

    testWidgets('the send button needs text', (tester) async {
      await _pump(tester);

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('thread-steer-send')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a finished thread on a gateway that cannot continue has no '
        'bar', (tester) async {
      await _pump(tester, support: ThreadSupport.stock, finished: true);

      expect(find.byKey(const Key('thread-steer-field')), findsNothing);
      expect(find.byKey(const Key('thread-continue-send')), findsNothing);
      expect(find.byType(ThreadSteerBar), findsOneWidget);
      expect(tester.getSize(find.byType(ThreadSteerBar)).height, 0);
    });
  });

  group('continue from the thread view', () {
    testWidgets('sends the follow-up and the thread runs again', (
      tester,
    ) async {
      final screen = await _pump(tester, finished: true);

      await tester.enterText(
        find.byKey(const Key('thread-steer-field')),
        'Make the summary shorter',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('thread-continue-send')));
      await threadFrames(tester);

      expect(
        screen.gateway.calls,
        contains('continue a|Make the summary shorter'),
      );
      expect(screen.threads.thread('a')!.state, AgentThreadState.running);
      expect(find.byKey(const Key('thread-live')), findsOneWidget);
      // Running again: the bar steers and stops.
      expect(find.byKey(const Key('thread-stop')), findsOneWidget);
    });

    testWidgets('with every slot in use the thread shows as queued', (
      tester,
    ) async {
      final screen = await _pump(tester, finished: true);
      screen.gateway.continueResult = const ThreadContinueResult(
        status: ThreadContinueStatus.queued,
        position: 2,
      );

      await tester.enterText(
        find.byKey(const Key('thread-steer-field')),
        'Make the summary shorter',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('thread-continue-send')));
      await threadFrames(tester);

      expect(screen.threads.thread('a')!.state, AgentThreadState.queued);
      expect(
        tester.widget<Text>(find.byKey(const Key('thread-meta'))).data,
        startsWith('Queued'),
      );
      expect(_status(tester), 'Follow-up queued. It starts when a slot frees.');
      expect(find.byKey(const Key('thread-steer-field')), findsNothing);
    });

    testWidgets('a refusal keeps the text and says why', (tester) async {
      final screen = await _pump(tester, finished: true);
      screen.gateway.continueResult = const ThreadContinueResult(
        status: ThreadContinueStatus.rejected,
        error: 'Delegation spawning is paused.',
      );

      await tester.enterText(
        find.byKey(const Key('thread-steer-field')),
        'Make the summary shorter',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('thread-continue-send')));
      await threadFrames(tester);

      expect(_status(tester), contains('Delegation spawning is paused.'));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('thread-steer-field')))
            .controller!
            .text,
        'Make the summary shorter',
      );
    });
  });

  group('parent chat', () {
    setUp(
      () => SharedPreferences.setMockInitialValues({'verbose_mode': false}),
    );

    testWidgets('the draft and the scroll offset survive opening and closing '
        'a thread', (tester) async {
      final messages = [
        for (var turn = 0; turn < 30; turn++) ...[
          {'id': turn * 2 + 1, 'role': 'user', 'content': 'Question $turn'},
          {
            'id': turn * 2 + 2,
            'role': 'assistant',
            'content': 'Answer $turn\n\nwith a second paragraph.',
          },
        ],
      ];
      final chat = await pumpThreadChat(tester, messages: messages);
      chat.emit(ThreadEventType.start, {
        'subagent_id': 'a',
        'goal': 'Audit dependency licences',
      });
      await threadFrames(tester);

      // An unsent draft, and a position away from the end of the list.
      await tester.enterText(find.byType(TextField), 'half-written thought');
      final list = find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.vertical,
      );
      ScrollPosition position() =>
          tester.widget<ListView>(list).controller!.position;
      await tester.drag(list, const Offset(0, 900));
      await threadFrames(tester);
      final offsetBefore = position().pixels;
      expect(position().maxScrollExtent, greaterThan(900));
      expect(offsetBefore, lessThan(position().maxScrollExtent));

      await tester.tap(find.byKey(const ValueKey<String>('thread-chip-a')));
      await threadFrames(tester);
      expect(find.byType(ThreadScreen), findsOneWidget);

      await tester.pageBack();
      await threadFrames(tester);

      expect(find.byType(ThreadScreen), findsNothing);
      final composer = tester.widget<TextField>(find.byType(TextField));
      expect(composer.controller!.text, 'half-written thought');
      expect(position().pixels, offsetBefore);
    });
  });
}
