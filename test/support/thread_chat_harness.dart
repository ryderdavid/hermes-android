import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/turn_notification_service.dart';
import 'package:hermes_android/core/services/ws_client.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;

import 'fake_threads_gateway.dart';

/// Serves `/api/sessions/<id>/messages` from in-memory transcripts, keyed by
/// session id, and counts the reads.
class ThreadChatHttpClient extends http.BaseClient {
  ThreadChatHttpClient([List<Map<String, dynamic>> messages = const []])
    : messages = List.of(messages);

  /// The parent chat's stored rows.
  List<Map<String, dynamic>> messages;

  /// Stored rows of child sessions (thread transcripts).
  final Map<String, List<Map<String, dynamic>>> children = {};

  /// Child sessions whose read fails.
  final Set<String> failing = {};
  final List<String> reads = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final segments = request.url.pathSegments;
    if (request.method == 'GET' &&
        segments.length >= 4 &&
        segments.last == 'messages') {
      final sessionId = segments[segments.length - 2];
      reads.add(sessionId);
      if (failing.contains(sessionId)) {
        return _json({'error': 'boom'}, statusCode: 500);
      }
      final rows = children[sessionId] ?? messages;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '');
      final offset = int.tryParse(
        request.url.queryParameters['offset'] ?? '0',
      )!;
      // order=latest: `offset` rows back from the newest, chronological.
      final end = (rows.length - offset).clamp(0, rows.length);
      final start = limit == null ? 0 : (end - limit).clamp(0, end);
      return _json({'data': rows.sublist(start, end)});
    }
    return _json({'error': 'unexpected request'}, statusCode: 404);
  }

  http.StreamedResponse _json(Object body, {int statusCode = 200}) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        statusCode,
        headers: {'content-type': 'application/json'},
      );
}

/// A remote prompt transport the test completes by hand.
class ControlledRemotePrompt {
  final List<String> prompts = [];
  Completer<void>? _completion;
  StreamCallback? _onEvent;

  Future<void> submit({
    required String sessionId,
    required String text,
    required StreamCallback onEvent,
    required void Function() onSent,
  }) async {
    onSent();
    prompts.add(text);
    _onEvent = onEvent;
    _completion = Completer<void>();
    await _completion!.future;
  }

  void emit(String type, Map<String, dynamic> data) {
    _onEvent!(StreamEvent(type: type, data: data));
  }

  void finish([String text = 'ok']) {
    emit('message.complete', {'text': text});
    _completion!.complete();
  }
}

/// A mounted `ChatScreen` with a fake thread gateway.
class ThreadChat {
  ThreadChat({
    required this.gateway,
    required this.http,
    required this.events,
    required this.remote,
  });

  final FakeThreadsGateway gateway;
  final ThreadChatHttpClient http;
  final TestDesktopAsyncEventHook events;
  final ControlledRemotePrompt remote;

  /// Delivers a gateway async event to the chat.
  void emit(String type, Map<String, dynamic> data) {
    events.handler!(StreamEvent(type: type, data: data));
  }
}

/// Pumps a `ChatScreen` whose thread and coordinator calls go to [gateway].
Future<ThreadChat> pumpThreadChat(
  WidgetTester tester, {
  FakeThreadsGateway? gateway,
  List<Map<String, dynamic>> messages = const [],
  String id = 'chat-1',
  String title = 'Release 3.2 planning',
  bool isLocalDraft = false,
  TurnNotificationService? notifications,
  ThemeData? theme,
}) async {
  final threadsGateway = gateway ?? FakeThreadsGateway();
  final client = ThreadChatHttpClient(messages);
  final events = TestDesktopAsyncEventHook();
  final remote = ControlledRemotePrompt();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? hermesTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChatScreen(
        connection: SavedConnection(
          id: 'conn-1',
          label: 'Fixture',
          host: 'fixture.example',
          port: 8642,
          apiKey: 'synthetic-test-key',
        ),
        session: Session(
          id: id,
          title: title,
          model: 'fixture-model',
          source: 'test',
          messageCount: messages.length,
          isActive: true,
          preview: '',
          startedAt: 1,
          isLocalDraft: isLocalDraft,
        ),
        testApiClient: ApiClient(
          baseUrl: 'http://fixture.example',
          apiKey: 'synthetic-test-key',
          httpClient: client,
        ),
        testRemotePromptSubmit: remote.submit,
        testDesktopAsyncEventHook: events,
        testThreadsGateway: threadsGateway,
        testTurnNotifications: notifications,
      ),
    ),
  );
  await threadFrames(tester);
  return ThreadChat(
    gateway: threadsGateway,
    http: client,
    events: events,
    remote: remote,
  );
}

/// Advances a few frames. Thread spinners never settle, so tests step.
Future<void> threadFrames(WidgetTester tester, [int frames = 12]) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
