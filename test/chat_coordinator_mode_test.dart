import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/agent_threads_controller.dart';
import 'package:hermes_android/core/services/coordinator_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_threads_gateway.dart';
import 'support/thread_chat_harness.dart';

const _menuItem = Key('chat-menu-coordinator');
const _label = Key('chat-coordinator-label');

/// The connection identity `ChatScreen` derives for the harness connection.
const _identity = 'http://fixture.example:8642||';

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Chat actions'));
  await tester.pumpAndSettle();
}

CheckedPopupMenuItem<String> _item(WidgetTester tester) =>
    tester.widget<CheckedPopupMenuItem<String>>(find.byKey(_menuItem));

Future<CoordinatorModeStore> _store() async =>
    CoordinatorModeStore(await SharedPreferences.getInstance());

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'verbose_mode': false}));

  testWidgets('off by default: enabled, unchecked, explained, no label', (
    tester,
  ) async {
    final gateway = FakeThreadsGateway(support: ThreadSupport.full);
    await pumpThreadChat(tester, gateway: gateway);

    expect(find.byKey(_label), findsNothing);
    await _openMenu(tester);

    expect(_item(tester).enabled, isTrue);
    expect(_item(tester).checked, isFalse);
    expect(find.text('Coordinator mode'), findsOneWidget);
    expect(find.text('Hand long work to threads'), findsOneWidget);
    expect(gateway.callCount('mode'), 0);
  });

  testWidgets('turning it on checks the item, shows the label, tells the '
      'gateway and is stored', (tester) async {
    final gateway = FakeThreadsGateway(support: ThreadSupport.full);
    await pumpThreadChat(tester, gateway: gateway);

    await _openMenu(tester);
    await tester.tap(find.byKey(_menuItem));
    await tester.pumpAndSettle();

    expect(gateway.calls.where((call) => call.startsWith('mode')), [
      'mode true',
    ]);
    expect(find.byKey(_label), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_label),
        matching: find.text('Coordinator'),
      ),
      findsOneWidget,
    );
    expect(
      (await _store()).read(connectionIdentity: _identity, sessionId: 'chat-1'),
      isTrue,
    );

    await _openMenu(tester);
    expect(_item(tester).checked, isTrue);

    // And off again.
    await tester.tap(find.byKey(_menuItem));
    await tester.pumpAndSettle();
    expect(gateway.calls.where((call) => call.startsWith('mode')), [
      'mode true',
      'mode false',
    ]);
    expect(find.byKey(_label), findsNothing);
    expect(
      (await _store()).read(connectionIdentity: _identity, sessionId: 'chat-1'),
      isFalse,
    );
  });

  testWidgets('the mode survives a restart and is re-sent when the chat '
      'binds', (tester) async {
    await (await _store()).save(
      connectionIdentity: _identity,
      sessionId: 'chat-1',
      enabled: true,
    );
    final gateway = FakeThreadsGateway(support: ThreadSupport.full);

    await pumpThreadChat(tester, gateway: gateway);

    expect(find.byKey(_label), findsOneWidget);
    expect(gateway.calls.where((call) => call.startsWith('mode')), [
      'mode true',
    ]);
    await _openMenu(tester);
    expect(_item(tester).checked, isTrue);
  });

  testWidgets('a gateway without the capability: disabled, with the reason', (
    tester,
  ) async {
    // The user had turned it on against an updated gateway before.
    await (await _store()).save(
      connectionIdentity: _identity,
      sessionId: 'chat-1',
      enabled: true,
    );
    final gateway = FakeThreadsGateway(support: ThreadSupport.stock);
    await pumpThreadChat(tester, gateway: gateway);

    expect(find.byKey(_label), findsNothing);
    await _openMenu(tester);

    expect(_item(tester).enabled, isFalse);
    expect(_item(tester).checked, isFalse);
    expect(find.text('The gateway must be updated'), findsOneWidget);
    expect(find.text('Hand long work to threads'), findsNothing);

    await tester.tap(find.byKey(_menuItem), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(gateway.callCount('mode'), 0);
    // The stored choice is untouched.
    expect(
      (await _store()).read(connectionIdentity: _identity, sessionId: 'chat-1'),
      isTrue,
    );
  });

  testWidgets('a new chat starts off', (tester) async {
    final gateway = FakeThreadsGateway(support: ThreadSupport.full);
    await pumpThreadChat(tester, gateway: gateway, isLocalDraft: true);

    expect(find.byKey(_label), findsNothing);
    expect(gateway.callCount('mode'), 0);
  });

  testWidgets('a new chat starts on when the default is on; an existing '
      'chat does not', (tester) async {
    await (await _store()).setNewChatsDefault(true);
    final gateway = FakeThreadsGateway(support: ThreadSupport.full);

    await pumpThreadChat(
      tester,
      gateway: gateway,
      id: 'draft-1',
      isLocalDraft: true,
    );

    expect(find.byKey(_label), findsOneWidget);
    expect(gateway.calls, contains('mode true'));
    // The chat now has its own value.
    expect(
      (await _store()).read(
        connectionIdentity: _identity,
        sessionId: 'draft-1',
      ),
      isTrue,
    );

    final existing = FakeThreadsGateway(support: ThreadSupport.full);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpThreadChat(tester, gateway: existing, id: 'old-chat');

    expect(find.byKey(_label), findsNothing);
    expect(existing.callCount('mode'), 0);
  });

  testWidgets('the prompt text is the same with the mode on and off', (
    tester,
  ) async {
    final gateway = FakeThreadsGateway(support: ThreadSupport.full);
    final chat = await pumpThreadChat(tester, gateway: gateway);
    const prompt = 'Audit the licences, draft the notes and check CI.';

    Future<void> send() async {
      await tester.enterText(find.byType(TextField), prompt);
      await tester.tap(find.byTooltip('Send'));
      await threadFrames(tester);
      chat.remote.finish();
      await tester.pumpAndSettle();
    }

    await send();
    await _openMenu(tester);
    await tester.tap(find.byKey(_menuItem));
    await tester.pumpAndSettle();
    await send();

    expect(chat.remote.prompts, [prompt, prompt]);
    expect(chat.remote.prompts[0].codeUnits, chat.remote.prompts[1].codeUnits);
  });
}
