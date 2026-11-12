// Coordinator mode against a fake gateway over a real loopback socket: what
// goes on the wire when the chat binds, when the mode is toggled, and when a
// prompt is sent. No widget binding: real WS traffic cannot share a suite
// with it.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/agent_threads_controller.dart';
import 'package:hermes_android/core/services/coordinator_mode_store.dart';
import 'package:hermes_android/core/services/desktop_gateway_client.dart';
import 'package:hermes_android/core/services/thread_wire.dart';
import 'package:hermes_android/core/services/turn_notification_service.dart';
import 'package:hermes_android/core/widgets/chat_threads_binding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_thread_gateway.dart';
import 'support/recording_turn_notification_sink.dart';

const _connectionIdentity = 'conn';
const _mobileId = 'mobile-1';

class _Chat {
  _Chat(this.gateway, this.client, this.binding, this.store);

  final FakeThreadGateway gateway;
  final DesktopGatewayClient client;
  final ChatThreadsBinding binding;
  final CoordinatorModeStore store;

  List<Object?> get modeCalls => [
    for (final request in gateway.requestsFor(ThreadRpc.sessionModeSet))
      (request['params'] as Map)['coordinator'],
  ];

  /// Sends one prompt the way the chat does and returns the exact
  /// `prompt.submit` params the gateway received.
  Future<String> send(String text) async {
    final before = gateway.requestsFor('prompt.submit').length;
    await binding.applyCoordinatorModeBeforeSend();
    await client.submitPrompt(
      sessionId: _mobileId,
      text: text,
      onEvent: (_) {},
      onSent: () {},
    );
    final submits = gateway.requestsFor('prompt.submit');
    expect(submits, hasLength(before + 1));
    return jsonEncode(submits.last['params']);
  }
}

Future<_Chat> _chat({
  required bool gatewaySupportsMode,
  bool storedOn = false,
  bool isNewChat = false,
  bool newChatsDefault = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = CoordinatorModeStore(await SharedPreferences.getInstance());
  if (storedOn) {
    await store.save(
      connectionIdentity: _connectionIdentity,
      sessionId: _mobileId,
      enabled: true,
    );
  }
  if (newChatsDefault) await store.setNewChatsDefault(true);

  final gateway = await FakeThreadGateway.start();
  addTearDown(gateway.stop);
  gateway.handlers[ThreadRpc.list] = (_) => rpcResult({'subagents': []});
  gateway.handlers[ThreadRpc.delegationStatus] = (_) =>
      rpcResult({'active': [], 'paused': false, 'max_concurrent_children': 3});
  if (gatewaySupportsMode) {
    gateway.sessionInfo = {
      'coordinator_mode': false,
      'capabilities': ThreadCapabilityKey.all.toList(),
    };
    gateway.handlers[ThreadRpc.sessionModeSet] = (params) =>
        rpcResult({'coordinator': params['coordinator'], 'pending': false});
  }

  final client = DesktopGatewayClient.fromConnection(gateway.connection());
  addTearDown(client.close);
  final binding = ChatThreadsBinding(
    gateway: DesktopThreadsGateway(client, sessionId: _mobileId),
    connectionIdentity: _connectionIdentity,
    connectionId: 'thread-test',
    sessionId: _mobileId,
    isNewChat: isNewChat,
    chatTitle: () => 'Chat',
    isAppInBackground: () => false,
    notifications: TurnNotificationService(
      sink: RecordingTurnNotificationSink(),
    ),
    notificationText: () => const ThreadNotificationText(
      finishedTitle: 'f',
      failedTitle: 'x',
      questionTitle: 'q',
      privateFinished: 'pf',
      privateAttention: 'pa',
    ),
    loadHistory: null,
    sendCoordinatorPrompt: (_) async => false,
    onThreadActivity: () {},
    store: Future.value(store),
  );
  addTearDown(binding.dispose);
  // ChatScreen wires the same listener.
  client.setSessionBoundListener(
    (local, stored) => binding.onSessionBound(stored),
  );
  return _Chat(gateway, client, binding, store);
}

void main() {
  test('the mode is sent when the chat binds, while it is on', () async {
    final chat = await _chat(gatewaySupportsMode: true, storedOn: true);

    await chat.client.ensureSession(_mobileId);
    await waitFor(() => chat.modeCalls.isNotEmpty);

    expect(chat.modeCalls, [true]);
    final params =
        chat.gateway.requestsFor(ThreadRpc.sessionModeSet).single['params']
            as Map;
    expect(params['session_id'], chat.gateway.lastRuntimeSessionId);
    expect(chat.binding.coordinatorActive, isTrue);
  });

  test('nothing is sent on bind while the mode is off', () async {
    final chat = await _chat(gatewaySupportsMode: true);

    await chat.client.ensureSession(_mobileId);
    await waitFor(
      () => chat.gateway.requestsFor(ThreadRpc.delegationStatus).isNotEmpty,
    );

    expect(chat.modeCalls, isEmpty);
    expect(chat.binding.coordinatorAvailable, isTrue);
    expect(chat.binding.coordinatorActive, isFalse);
  });

  test('toggling sends the new value and stores it', () async {
    final chat = await _chat(gatewaySupportsMode: true);
    await chat.client.ensureSession(_mobileId);
    await waitFor(() => chat.binding.coordinatorAvailable);

    await chat.binding.toggleCoordinator();
    expect(chat.modeCalls, [true]);
    expect(
      chat.store.read(
        connectionIdentity: _connectionIdentity,
        sessionId: _mobileId,
      ),
      isTrue,
    );
    // The chat is listed under its stored id after a restart.
    expect(
      chat.store.read(
        connectionIdentity: _connectionIdentity,
        sessionId: 'stored-1',
      ),
      isTrue,
    );

    await chat.binding.toggleCoordinator();
    expect(chat.modeCalls, [true, false]);
    expect(
      chat.store.read(
        connectionIdentity: _connectionIdentity,
        sessionId: _mobileId,
      ),
      isFalse,
    );
  });

  test('a reconnect binds again and sends the mode again', () async {
    final chat = await _chat(gatewaySupportsMode: true, storedOn: true);
    await chat.client.ensureSession(_mobileId);
    await waitFor(() => chat.modeCalls.length == 1);

    await chat.gateway.dropSockets();

    await waitFor(() => chat.modeCalls.length == 2);
    expect(chat.modeCalls, [true, true]);
    expect(chat.gateway.connectionCount, 2);
  });

  test('a new chat takes the default and is in the mode before its first '
      'prompt', () async {
    final chat = await _chat(
      gatewaySupportsMode: true,
      isNewChat: true,
      newChatsDefault: true,
    );
    await waitFor(() => chat.binding.coordinatorOn);

    // No session yet: the first send creates it.
    expect(chat.modeCalls, isEmpty);
    await chat.send('Plan the release');

    final methods = [
      for (final request in chat.gateway.requests) request['method'],
    ];
    expect(
      methods.indexOf(ThreadRpc.sessionModeSet),
      lessThan(methods.indexOf('prompt.submit')),
    );
    expect(chat.modeCalls.first, isTrue);
  });

  test('prompt payloads are byte-identical with the mode on and off', () async {
    final chat = await _chat(gatewaySupportsMode: true);
    await chat.client.ensureSession(_mobileId);
    await waitFor(() => chat.binding.coordinatorAvailable);
    const prompt = 'Audit the licences, draft the notes and check CI.';

    final off = await chat.send(prompt);
    await chat.binding.toggleCoordinator();
    final on = await chat.send(prompt);
    await chat.binding.toggleCoordinator();
    final offAgain = await chat.send(prompt);

    expect(chat.modeCalls, [true, false]);
    expect(on, off);
    expect(offAgain, off);
    expect(jsonDecode(on), {
      'session_id': chat.gateway.lastRuntimeSessionId,
      'text': prompt,
    });
  });

  test('a gateway without the capability gets no mode call and the same '
      'prompt', () async {
    final chat = await _chat(gatewaySupportsMode: false, storedOn: true);
    await chat.client.ensureSession(_mobileId);
    await waitFor(() => chat.gateway.requestsFor(ThreadRpc.list).isNotEmpty);
    const prompt = 'Audit the licences, draft the notes and check CI.';

    expect(chat.binding.coordinatorAvailable, isFalse);
    expect(chat.binding.coordinatorActive, isFalse);
    await chat.binding.toggleCoordinator();
    final sent = await chat.send(prompt);

    expect(chat.modeCalls, isEmpty);
    expect(jsonDecode(sent), {
      'session_id': chat.gateway.lastRuntimeSessionId,
      'text': prompt,
    });
    // The stored choice is kept for when the gateway is updated.
    expect(
      chat.store.read(
        connectionIdentity: _connectionIdentity,
        sessionId: _mobileId,
      ),
      isTrue,
    );
  });
}
