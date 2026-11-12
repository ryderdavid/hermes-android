import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/thread_screen.dart';
import 'package:hermes_android/core/services/agent_threads_controller.dart';
import 'package:hermes_android/core/services/thread_wire.dart';
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
}
