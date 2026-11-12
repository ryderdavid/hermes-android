import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/agent_threads_controller.dart';
import 'package:hermes_android/core/services/notification_prefs.dart';
import 'package:hermes_android/core/services/thread_wire.dart';
import 'package:hermes_android/core/services/turn_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_threads_gateway.dart';
import 'support/recording_turn_notification_sink.dart';
import 'support/thread_chat_harness.dart';

/// ChatScreen asks for a thread notification when a thread finishes, fails
/// or asks a question while the app is away. What the service then posts is
/// covered in turn_notification_service_test.dart.
void main() {
  late RecordingTurnNotificationSink sink;
  late TurnNotificationService notifications;

  setUp(() {
    SharedPreferences.setMockInitialValues({'verbose_mode': false});
    sink = RecordingTurnNotificationSink();
    notifications = TurnNotificationService(sink: sink);
    notificationPrefs.value = NotificationPrefs.defaults;
  });

  // Android walks the full lifecycle chain; tests move the same way.
  void background(WidgetTester tester) {
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  void foreground(WidgetTester tester) {
    for (final state in const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  Future<ThreadChat> chatWithThread(WidgetTester tester) async {
    final chat = await pumpThreadChat(
      tester,
      gateway: FakeThreadsGateway(support: ThreadSupport.full),
      notifications: notifications,
    );
    chat.emit(ThreadEventType.start, {
      'subagent_id': 'notes',
      'goal': 'Draft release notes',
      'delegation_id': 'deleg_1',
    });
    await threadFrames(tester);
    return chat;
  }

  testWidgets('a thread finishing in the background notifies with its goal '
      'and outcome', (tester) async {
    final chat = await chatWithThread(tester);
    background(tester);
    await tester.pump();

    chat.emit(ThreadEventType.complete, {
      'subagent_id': 'notes',
      'goal': 'Draft release notes',
      'status': 'completed',
      'summary': 'Drafted 9 user-facing changes.',
    });
    await threadFrames(tester);

    final shown = sink.shown.single;
    expect(shown.title, 'Thread finished — Release 3.2 planning');
    expect(shown.body, 'Draft release notes\nDrafted 9 user-facing changes.');
    expect(jsonDecode(shown.payload), {
      'sessionId': 'chat-1',
      'connectionId': 'conn-1',
      'threadId': 'notes',
    });
    foreground(tester);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a failed thread notifies as a failure', (tester) async {
    final chat = await chatWithThread(tester);
    background(tester);
    await tester.pump();

    chat.emit(ThreadEventType.complete, {
      'subagent_id': 'notes',
      'goal': 'Draft release notes',
      'status': 'error',
      'summary': 'gh not installed',
    });
    await threadFrames(tester);

    expect(sink.shown.single.title, 'Thread failed — Release 3.2 planning');
    foreground(tester);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a thread question in the background notifies as input needed', (
    tester,
  ) async {
    final chat = await chatWithThread(tester);
    background(tester);
    await tester.pump();

    chat.emit(ThreadEventType.question, {
      'subagent_id': 'notes',
      'question_id': 'q1',
      'status': 'pending',
      'goal': 'Draft release notes',
      'text': 'Include the Office preview work?',
    });
    await threadFrames(tester);

    final shown = sink.shown.single;
    expect(shown.title, 'A thread needs you — Release 3.2 planning');
    expect(shown.body, 'Draft release notes\nInclude the Office preview work?');
    expect(shown.channel.id, TurnNotificationService.attentionChannel.id);
    foreground(tester);
    await tester.pump();
  });

  testWidgets('nothing is posted while the chat is on screen', (tester) async {
    final chat = await chatWithThread(tester);

    chat.emit(ThreadEventType.question, {
      'subagent_id': 'notes',
      'question_id': 'q1',
      'status': 'pending',
      'text': 'Include the Office preview work?',
    });
    chat.emit(ThreadEventType.complete, {
      'subagent_id': 'notes',
      'status': 'completed',
    });
    await threadFrames(tester);
    await tester.pump(const Duration(seconds: 3));

    expect(sink.shown, isEmpty);
  });

  testWidgets('with content hidden the notification names nothing', (
    tester,
  ) async {
    notificationPrefs.value = notificationPrefs.value.copyWith(
      hideContent: true,
    );
    final chat = await chatWithThread(tester);
    background(tester);
    await tester.pump();

    chat.emit(ThreadEventType.complete, {
      'subagent_id': 'notes',
      'goal': 'Draft release notes',
      'status': 'completed',
      'summary': 'Drafted 9 user-facing changes.',
    });
    await threadFrames(tester);

    final shown = sink.shown.single;
    expect(shown.title, 'Thread finished');
    expect(shown.body, 'A thread finished.');
    foreground(tester);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a thread the user stopped does not notify', (tester) async {
    final chat = await chatWithThread(tester);
    await tester.tap(find.byKey(const Key('threads-strip-all')));
    await threadFrames(tester);
    await tester.tap(find.byKey(const ValueKey<String>('thread-stop-notes')));
    await threadFrames(tester);
    await tester.tapAt(const Offset(10, 10));
    await threadFrames(tester);
    background(tester);
    await tester.pump();

    chat.emit(ThreadEventType.complete, {
      'subagent_id': 'notes',
      'status': 'interrupted',
    });
    await threadFrames(tester);

    expect(sink.shown, isEmpty);
    foreground(tester);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('an approval raised by a thread names the chat and the thread', (
    tester,
  ) async {
    final chat = await chatWithThread(tester);
    background(tester);
    await tester.pump();

    chat.emit('approval.request', {
      'server_request_id': '1.1:srq-thread',
      'command': 'gh run rerun 18734 --failed',
      'description': 'Re-run the failing Android jobs.',
      'choices': ['once', 'deny'],
      'subagent_id': 'ci',
      'goal': 'Check CI matrix',
    });
    await tester.pump();

    final shown = sink.shown.single;
    expect(
      shown.title,
      'Approval needed — Release 3.2 planning · Check CI matrix',
    );
    expect(shown.body, 'gh run rerun 18734 --failed');
    expect(jsonDecode(shown.payload), {
      'sessionId': 'chat-1',
      'connectionId': 'conn-1',
      'requestId': '1.1:srq-thread',
    });
    foreground(tester);
    await tester.pump();
  });
}
