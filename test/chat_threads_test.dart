import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/agent_thread.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/screens/thread_screen.dart';
import 'package:hermes_android/core/services/agent_threads_controller.dart';
import 'package:hermes_android/core/services/thread_wire.dart';
import 'package:hermes_android/core/services/ws_client.dart';
import 'package:hermes_android/core/widgets/gateway_insight_card.dart';
import 'package:hermes_android/core/widgets/thread_cards.dart';
import 'package:hermes_android/core/widgets/threads_sheet.dart';
import 'package:hermes_android/core/widgets/threads_strip.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_threads_gateway.dart';
import 'support/thread_chat_harness.dart';

Map<String, dynamic> _thread(
  String id,
  String goal, [
  Map<String, dynamic>? more,
]) => {
  'subagent_id': id,
  'goal': goal,
  'task_index': 0,
  'task_count': 1,
  ...?more,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'verbose_mode': false}));

  group('roster in the chat', () {
    testWidgets('a chat without threads looks as it did', (tester) async {
      await pumpThreadChat(tester);

      expect(find.byType(ThreadsStrip), findsNothing);
      expect(find.byKey(const Key('threads-strip')), findsNothing);
      expect(find.byType(GatewaySubagentCard), findsNothing);
    });

    testWidgets('the strip appears when the gateway reports a thread', (
      tester,
    ) async {
      final chat = await pumpThreadChat(tester);

      chat.emit(
        ThreadEventType.start,
        _thread('a', 'Audit dependency licences'),
      );
      await threadFrames(tester);

      expect(find.byKey(const Key('threads-strip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ThreadsStrip),
          matching: find.text('Audit dependency licences'),
        ),
        findsOneWidget,
      );
      // No read-only list next to the roster.
      expect(find.byType(GatewaySubagentCard), findsNothing);
    });

    testWidgets('the roster is read when the session binds', (tester) async {
      final gateway = FakeThreadsGateway()
        ..roster = ThreadRosterSnapshot(
          threads: [
            rosterRow('a', goal: 'Audit dependency licences'),
            rosterRow(
              'b',
              goal: 'Check CI matrix',
              question: {'question_id': 'q1', 'text': 'Re-run?'},
            ),
          ],
        );
      await pumpThreadChat(tester, gateway: gateway);

      expect(gateway.calls, containsAllInOrder(['probe', 'list', 'status']));
      final strip = tester.widget<ThreadsStrip>(find.byType(ThreadsStrip));
      // The thread that needs the user comes first.
      expect(strip.threads.map((thread) => thread.id), ['b', 'a']);
    });

    testWidgets('All opens the sheet; a chip opens the thread', (tester) async {
      final chat = await pumpThreadChat(tester);
      chat.emit(ThreadEventType.start, _thread('a', 'Audit licences'));
      await threadFrames(tester);

      await tester.tap(find.byKey(const Key('threads-strip-all')));
      await threadFrames(tester);
      expect(find.byType(ThreadsSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await threadFrames(tester);

      await tester.tap(find.byKey(const ValueKey<String>('thread-chip-a')));
      await threadFrames(tester);
      expect(find.byType(ThreadScreen), findsOneWidget);
    });
  });

  group('gateway without thread support', () {
    testWidgets('keeps the read-only task list, with no roster or cards', (
      tester,
    ) async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.none);
      final chat = await pumpThreadChat(tester, gateway: gateway);

      chat.emit(
        ThreadEventType.start,
        _thread('a', 'Audit dependency licences', {'model': 'sonnet'}),
      );
      chat.emit(
        ThreadEventType.tool,
        _thread('a', 'Audit dependency licences', {'tool_name': 'terminal'}),
      );
      await threadFrames(tester);

      expect(find.byType(GatewaySubagentCard), findsOneWidget);
      final card = tester.widget<GatewaySubagentCard>(
        find.byType(GatewaySubagentCard),
      );
      expect(card.activities.single.goal, 'Audit dependency licences');
      expect(card.activities.single.detail, 'terminal');
      expect(find.byKey(const Key('threads-strip')), findsNothing);
      expect(find.byType(ThreadsStartedCard), findsNothing);
      // Only the probe: nothing else is asked of a gateway that cannot answer.
      expect(gateway.calls, ['probe']);
    });

    testWidgets('a failed probe is the same as no support', (tester) async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.none)
        ..failures['probe'] = StateError('unknown method');
      final chat = await pumpThreadChat(tester, gateway: gateway);

      chat.emit(ThreadEventType.start, _thread('a', 'Audit'));
      await threadFrames(tester);

      expect(find.byType(GatewaySubagentCard), findsOneWidget);
      expect(find.byKey(const Key('threads-strip')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Started N threads card', () {
    testWidgets('one card lists the threads a turn started, and its rows '
        'follow each thread', (tester) async {
      final chat = await pumpThreadChat(
        tester,
        messages: [
          {'id': 1, 'role': 'user', 'content': 'Plan the 3.2 release'},
          {'id': 2, 'role': 'assistant', 'content': 'On it.'},
        ],
      );

      for (final (id, goal) in [
        ('a', 'Audit dependency licences'),
        ('b', 'Draft release notes'),
        ('c', 'Check CI matrix'),
      ]) {
        chat.emit(ThreadEventType.spawnRequested, _thread(id, goal));
      }
      await threadFrames(tester);

      expect(find.byType(ThreadsStartedCard), findsOneWidget);
      expect(find.text('Started 3 threads'), findsOneWidget);
      String row(String id) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(ValueKey<String>('started-thread-$id')),
              matching: find.textContaining(
                RegExp('Running|Done|Failed|Needs'),
              ),
            ),
          )
          .data!;
      expect(row('a'), startsWith('Running'));
      expect(row('b'), startsWith('Running'));

      chat.emit(
        ThreadEventType.tool,
        _thread('a', 'Audit dependency licences', {'tool_name': 'terminal'}),
      );
      chat.emit(
        ThreadEventType.complete,
        _thread('b', 'Draft release notes', {
          'status': 'completed',
          'tool_count': 12,
        }),
      );
      chat.emit(
        ThreadEventType.complete,
        _thread('c', 'Check CI matrix', {'status': 'error'}),
      );
      await threadFrames(tester);

      expect(row('a'), startsWith('Running · 1 tool'));
      expect(row('b'), startsWith('Done · 12 tools'));
      expect(row('c'), startsWith('Failed'));
      expect(find.byType(ThreadsStartedCard), findsOneWidget);
    });

    testWidgets('a row opens its thread', (tester) async {
      final chat = await pumpThreadChat(
        tester,
        messages: [
          {'id': 1, 'role': 'user', 'content': 'Plan the 3.2 release'},
        ],
      );
      chat.emit(ThreadEventType.start, _thread('a', 'Audit licences'));
      await threadFrames(tester);

      await tester.tap(find.byKey(const ValueKey<String>('started-thread-a')));
      await threadFrames(tester);

      expect(find.byType(ThreadScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('thread report card', () {
    const report =
        '[ASYNC DELEGATION COMPLETE — deleg_1]\n'
        'A background subagent you dispatched earlier has finished.\n\n'
        'Original goal: Draft release notes\n'
        'Status: completed   Duration: 240.0s\n'
        '--- RESULT ---\n'
        'Drafted docs/releases/v3.2.0-you.1.md.';

    List<Map<String, dynamic>> history({Map<String, dynamic>? metadata}) => [
      {'id': 1, 'role': 'user', 'content': 'Friday'},
      {'id': 2, 'role': 'assistant', 'content': 'Friday it is.'},
      {
        'id': 3,
        'role': 'user',
        'content': report,
        'display_kind': 'async_delegation_complete',
        'display_metadata': ?metadata,
      },
      {'id': 4, 'role': 'assistant', 'content': 'The notes are drafted.'},
    ];

    const annotated = {
      'delegation_id': 'deleg_1',
      'threads': [
        {
          'subagent_id': 'notes',
          'task_index': 0,
          'goal': 'Draft release notes',
          'status': 'completed',
          'tool_count': 12,
          'duration_seconds': 240.0,
        },
      ],
    };

    testWidgets('stands in for the raw result block; the coordinator\'s '
        'reply is a normal message', (tester) async {
      await pumpThreadChat(tester, messages: history());

      expect(find.byType(ThreadReportCard), findsOneWidget);
      expect(find.text('Draft release notes · finished'), findsOneWidget);
      expect(
        find.text('Drafted docs/releases/v3.2.0-you.1.md.'),
        findsOneWidget,
      );
      expect(find.textContaining('ASYNC DELEGATION'), findsNothing);
      expect(find.textContaining('Original goal'), findsNothing);
      final bubbles = tester
          .widgetList<MessageBubble>(find.byType(MessageBubble))
          .map(
            (bubble) => '${bubble.isUser ? 'user' : 'bot'}:${bubble.content}',
          );
      expect(bubbles, [
        'user:Friday',
        'bot:Friday it is.',
        'bot:The notes are drafted.',
      ]);
    });

    testWidgets('Continue is hidden until the gateway can continue threads', (
      tester,
    ) async {
      await pumpThreadChat(
        tester,
        gateway: FakeThreadsGateway(support: ThreadSupport.stock),
        messages: history(metadata: annotated),
      );

      expect(find.text('Open thread'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('Continue sends the follow-up to that thread', (tester) async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full);
      await pumpThreadChat(
        tester,
        gateway: gateway,
        messages: history(metadata: annotated),
      );

      await tester.tap(find.text('Continue'));
      await threadFrames(tester);
      expect(find.text('Continue Draft release notes'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('thread-text-field')),
        'Make the summary shorter',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('thread-text-send')));
      await threadFrames(tester);

      expect(
        gateway.calls,
        contains('continue notes|Make the summary shorter'),
      );
      expect(find.text('The thread is running again.'), findsOneWidget);
      // The same thread, running: the roster shows it.
      final strip = tester.widget<ThreadsStrip>(find.byType(ThreadsStrip));
      expect(strip.threads.single.id, 'notes');
      expect(strip.threads.single.state, AgentThreadState.running);
    });

    testWidgets('with every slot in use the follow-up is queued', (
      tester,
    ) async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full)
        ..continueResult = const ThreadContinueResult(
          status: ThreadContinueStatus.queued,
          position: 1,
        );
      await pumpThreadChat(
        tester,
        gateway: gateway,
        messages: history(metadata: annotated),
      );

      await tester.tap(find.text('Continue'));
      await threadFrames(tester);
      await tester.enterText(
        find.byKey(const Key('thread-text-field')),
        'Shorter',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('thread-text-send')));
      await threadFrames(tester);

      expect(
        find.text('Follow-up queued. It starts when a slot frees.'),
        findsOneWidget,
      );
      final strip = tester.widget<ThreadsStrip>(find.byType(ThreadsStrip));
      expect(strip.threads.single.state, AgentThreadState.queued);
    });

    testWidgets('a report without a thread id is matched to the roster by '
        'its delegation', (tester) async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full);
      // The REST history carries display_kind but no annotation.
      final chat = await pumpThreadChat(
        tester,
        gateway: gateway,
        messages: history(),
      );
      expect(find.text('Open thread'), findsNothing);

      chat.emit(
        ThreadEventType.complete,
        _thread('notes', 'Draft release notes', {
          'status': 'completed',
          'delegation_id': 'deleg_1',
        }),
      );
      await threadFrames(tester);

      expect(find.text('Open thread'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('thread messages', () {
    const updateRow =
        '[THREAD UPDATE — ci]\n'
        'A background thread you started sent an interim update.\n'
        'Thread task: Check CI matrix\n'
        '--- UPDATE ---\n'
        '2 of 5 jobs fail on Android API 35.';
    const questionPayload = {
      'type': 'async_delegation_message',
      'message_id': 'dmsg_2',
      'kind': 'question',
      'text': 'Drop the two AGPL packages, or flag them for legal?',
      'subagent_id': 'licences',
      'goal': 'Audit dependency licences',
      'question_id': 'q1',
    };

    Future<ThreadChat> asked(
      WidgetTester tester, {
      ThreadSupport support = ThreadSupport.full,
    }) async {
      final chat = await pumpThreadChat(
        tester,
        gateway: FakeThreadsGateway(support: support),
      );
      chat.emit(
        ThreadEventType.start,
        _thread('licences', 'Audit dependency licences'),
      );
      chat.emit(ThreadEventType.question, {
        'subagent_id': 'licences',
        'question_id': 'q1',
        'status': 'pending',
        'goal': 'Audit dependency licences',
        'text': 'Drop the two AGPL packages, or flag them for legal?',
      });
      chat.emit(ThreadEventType.message, questionPayload);
      await threadFrames(tester);
      return chat;
    }

    Card card(WidgetTester tester) => tester.widget<Card>(
      find.descendant(
        of: find.byType(ThreadMessageCard),
        matching: find.byType(Card),
      ),
    );

    testWidgets('an update turn is a card naming the thread, with Open '
        'thread', (tester) async {
      final chat = await pumpThreadChat(
        tester,
        gateway: FakeThreadsGateway(support: ThreadSupport.full),
        messages: [
          {
            'id': 5,
            'role': 'user',
            'content': updateRow,
            'display_kind': 'async_delegation_message',
          },
          {'id': 6, 'role': 'assistant', 'content': 'CI has two failures.'},
        ],
      );
      chat.emit(ThreadEventType.start, _thread('ci', 'Check CI matrix'));
      await threadFrames(tester);

      expect(find.text('Check CI matrix · update'), findsOneWidget);
      expect(find.text('2 of 5 jobs fail on Android API 35.'), findsOneWidget);
      expect(find.textContaining('THREAD UPDATE'), findsNothing);
      expect(card(tester).color, isNull);
      expect(find.text('Reply'), findsNothing);

      await tester.tap(find.text('Open thread'));
      await threadFrames(tester);
      expect(find.byType(ThreadScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an update delivered live shows before the history has it, '
        'and only once after', (tester) async {
      final chat = await pumpThreadChat(
        tester,
        gateway: FakeThreadsGateway(support: ThreadSupport.full),
      );
      chat.emit(ThreadEventType.message, {
        'type': 'async_delegation_message',
        'message_id': 'dmsg_1',
        'kind': 'update',
        'text': '2 of 5 jobs fail on Android API 35.',
        'subagent_id': 'ci',
        'goal': 'Check CI matrix',
      });
      await threadFrames(tester);
      expect(find.byType(ThreadMessageCard), findsOneWidget);

      // The gateway's turn is stored; the chat reads it once it is idle.
      chat.http.messages = [
        {'id': 5, 'role': 'user', 'content': updateRow},
        {'id': 6, 'role': 'assistant', 'content': 'CI has two failures.'},
      ];
      await tester.pump(const Duration(seconds: 3));
      await threadFrames(tester);

      expect(find.byType(ThreadMessageCard), findsOneWidget);
      expect(find.text('CI has two failures.'), findsOneWidget);
    });

    testWidgets('a question is emphasised, offers Reply and Let coordinator '
        'decide, and the thread needs you', (tester) async {
      await asked(tester);

      final scheme = Theme.of(
        tester.element(find.byType(ThreadMessageCard)),
      ).colorScheme;
      expect(find.text('Audit dependency licences asks'), findsOneWidget);
      expect(card(tester).color, scheme.tertiaryContainer);
      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Let coordinator decide'), findsOneWidget);
      expect(find.text('Open thread'), findsOneWidget);
      final strip = tester.widget<ThreadsStrip>(find.byType(ThreadsStrip));
      expect(strip.threads.single.state, AgentThreadState.needsYou);
    });

    testWidgets('Reply delivers the answer to that thread; the card shows '
        'it and who gave it', (tester) async {
      final chat = await asked(tester);

      await tester.tap(find.text('Reply'));
      await threadFrames(tester);
      expect(find.text('Reply to Audit dependency licences'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('thread-text-field')),
        'Flag them for legal',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('thread-text-send')));
      await threadFrames(tester);

      expect(
        chat.gateway.calls,
        contains('reply licences|q1|Flag them for legal'),
      );
      expect(find.text('You answered: Flag them for legal'), findsOneWidget);
      expect(find.text('Reply'), findsNothing);
      expect(find.text('Let coordinator decide'), findsNothing);
      expect(card(tester).color, isNull);
      final strip = tester.widget<ThreadsStrip>(find.byType(ThreadsStrip));
      expect(strip.threads.single.state, AgentThreadState.running);
    });

    testWidgets('Let coordinator decide sends the coordinator prompt, not a '
        'reply; the card records the coordinator\'s answer', (tester) async {
      final chat = await asked(tester);
      // An unsent draft must survive the prompt.
      await tester.enterText(find.byType(TextField), 'my draft');

      await tester.tap(find.text('Let coordinator decide'));
      await threadFrames(tester);

      expect(chat.remote.prompts, [
        "Answer thread licences's question yourself.",
      ]);
      expect(chat.gateway.callCount('reply'), 0);
      expect(find.text('Asked the coordinator to decide…'), findsOneWidget);
      expect(find.text('Reply'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'my draft',
      );

      chat.emit(ThreadEventType.question, {
        'subagent_id': 'licences',
        'question_id': 'q1',
        'status': 'answered',
        'answered_by': 'coordinator',
        'answer': 'Flag them for legal.',
      });
      chat.remote.finish();
      await tester.pump(const Duration(seconds: 3));
      await threadFrames(tester);

      expect(
        find.text('The coordinator answered: Flag them for legal.'),
        findsOneWidget,
      );
    });

    testWidgets('a duplicate reply is rejected: the card closes and says '
        'why', (tester) async {
      final chat = await asked(tester);
      chat.gateway.failures['reply'] = JsonRpcError(
        ThreadRpc.reply,
        'Question q1 is closed: it was already answered by the coordinator.',
        code: ThreadReplyWire.closedCode,
      );

      await tester.tap(find.text('Reply'));
      await threadFrames(tester);
      await tester.enterText(
        find.byKey(const Key('thread-text-field')),
        'Drop them',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('thread-text-send')));
      await threadFrames(tester);

      expect(
        find.text(
          'Question q1 is closed: it was already answered by the coordinator.',
        ),
        findsOneWidget,
      );
      expect(find.text('No longer waiting for an answer.'), findsOneWidget);
      expect(find.text('Reply'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unanswered question expires: marked expired, and the '
        'thread leaves needs-you', (tester) async {
      final chat = await asked(tester);

      chat.emit(ThreadEventType.question, {
        'subagent_id': 'licences',
        'question_id': 'q1',
        'status': 'expired',
      });
      await threadFrames(tester);

      expect(
        find.text('Expired without an answer. The thread carried on.'),
        findsOneWidget,
      );
      expect(find.text('Reply'), findsNothing);
      final strip = tester.widget<ThreadsStrip>(find.byType(ThreadsStrip));
      expect(strip.threads.single.state, AgentThreadState.running);
    });

    testWidgets('a stored question whose thread no longer waits is closed', (
      tester,
    ) async {
      await pumpThreadChat(
        tester,
        gateway: FakeThreadsGateway(support: ThreadSupport.full),
        messages: [
          {
            'id': 9,
            'role': 'user',
            'content':
                '[THREAD QUESTION — licences, question q1]\n'
                'Thread task: Audit dependency licences\n'
                '--- QUESTION ---\nDrop them?',
          },
        ],
      );

      expect(find.text('Audit dependency licences asks'), findsOneWidget);
      expect(find.text('No longer waiting for an answer.'), findsOneWidget);
      expect(find.text('Reply'), findsNothing);
    });

    testWidgets('options answer in one tap', (tester) async {
      final chat = await pumpThreadChat(
        tester,
        gateway: FakeThreadsGateway(support: ThreadSupport.full),
      );
      chat.emit(ThreadEventType.start, _thread('licences', 'Audit licences'));
      chat.emit(ThreadEventType.question, {
        'subagent_id': 'licences',
        'question_id': 'q1',
        'status': 'pending',
        'text': 'Drop them?',
      });
      chat.emit(ThreadEventType.message, {
        ...questionPayload,
        'options': ['Drop', 'Flag for legal'],
      });
      await threadFrames(tester);

      await tester.tap(find.text('Flag for legal'));
      await threadFrames(tester);

      expect(chat.gateway.calls, contains('reply licences|q1|Flag for legal'));
    });

    testWidgets('a gateway without thread messages gets no reply controls', (
      tester,
    ) async {
      await asked(tester, support: ThreadSupport.stock);

      expect(find.text('Reply'), findsNothing);
      expect(find.text('Let coordinator decide'), findsNothing);
    });
  });
}
