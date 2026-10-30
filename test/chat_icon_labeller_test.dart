import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/chat_icons/chat_icon_labeller.dart';
import 'package:hermes_android/core/chat_icons/chat_icon_store.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Call {
  _Call(this.sessionId, this.system, this.user);
  final String sessionId;
  final String system;
  final String user;

  List<Map<String, dynamic>> get chats =>
      ((jsonDecode(user) as Map)['chats'] as List).cast<Map<String, dynamic>>();
}

void main() {
  late SharedPreferences prefs;
  late ChatIconStore store;
  final day = DateTime.utc(2026, 10, 30, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    ChatIconStore.resetCache();
    store = ChatIconStore.forConnection(prefs, 'home');
  });

  ChatIconLabeller labeller(
    List<_Call> calls,
    Future<String> Function(_Call call) answer, {
    DateTime Function()? clock,
  }) => ChatIconLabeller(
    store: store,
    clock: clock ?? () => day,
    complete: ({required sessionId, required system, required user}) {
      final call = _Call(sessionId, system, user);
      calls.add(call);
      return answer(call);
    },
  );

  test('sends titles in one batch to the day\'s hidden session', () async {
    final calls = <_Call>[];
    final subject = labeller(
      calls,
      (_) async => '```json\n{"a":"yard","b":"payments"}\n```',
    );
    subject.request('a', 'Fix the garden');
    subject.request('b', 'Quarterly budget');
    await subject.flush();

    expect(calls, hasLength(1));
    expect(calls.single.sessionId, 'hermes-android-chat-icons-20261030');
    expect(calls.single.chats, [
      {'id': 'a', 'title': 'Fix the garden'},
      {'id': 'b', 'title': 'Quarterly budget'},
    ]);
    expect(calls.single.system, contains('yard'));
    expect(store.topicFor('a', 'Fix the garden')?.name, 'yard');
    expect(store.topicFor('b', 'Quarterly budget')?.name, 'payments');
    subject.dispose();
  });

  test('ignores names outside the vocabulary and ids it did not ask', () async {
    final calls = <_Call>[];
    final subject = labeller(
      calls,
      (_) async => 'Sure! {"a":"not_an_icon","b":"yard","x":"pets"}',
    );
    subject.request('a', 'One');
    subject.request('b', 'Two');
    await subject.flush();

    expect(store.topicFor('a', 'One'), isNull);
    expect(store.topicFor('b', 'Two')?.name, 'yard');
    expect(store.topicFor('x', 'Anything'), isNull);

    // A chat Hermes left out is not sent again for the same title...
    subject.request('a', 'One');
    await subject.flush();
    expect(calls, hasLength(1));
    // ...but a renamed chat is.
    subject.request('a', 'Dog walking');
    await subject.flush();
    expect(calls, hasLength(2));
    expect(calls.last.chats.single['title'], 'Dog walking');
    subject.dispose();
  });

  test('a renamed chat loses its stale label', () async {
    await store.putAll({'a': (icon: 'yard', title: 'Garden')});
    expect(store.topicFor('a', 'Garden')?.name, 'yard');
    expect(store.topicFor('a', 'Budget'), isNull);
  });

  test('labels survive a restart', () async {
    await store.putAll({'a': (icon: 'yard', title: 'Garden')});
    final reopened = ChatIconStore(prefs, 'home');
    expect(reopened.topicFor('a', 'Garden')?.name, 'yard');
    expect(ChatIconStore(prefs, 'other').topicFor('a', 'Garden'), isNull);
  });

  test('a failed batch backs off, then retries the same chats', () async {
    var now = day;
    final calls = <_Call>[];
    var fail = true;
    final subject = labeller(calls, (_) async {
      if (fail) throw Exception('gateway down');
      return '{"a":"yard"}';
    }, clock: () => now);
    subject.request('a', 'Garden');
    await subject.flush();
    expect(calls, hasLength(1));
    expect(store.topicFor('a', 'Garden'), isNull);

    // Still inside the back-off: nothing is sent.
    fail = false;
    now = day.add(const Duration(minutes: 1));
    await subject.flush();
    expect(calls, hasLength(1));

    now = day.add(const Duration(minutes: 6));
    await subject.flush();
    expect(calls, hasLength(2));
    expect(store.topicFor('a', 'Garden')?.name, 'yard');
    subject.dispose();
  });

  test('clearing forgets labels and what was asked', () async {
    final calls = <_Call>[];
    final subject = labeller(calls, (_) async => '{"a":"yard"}');
    subject.request('a', 'Garden');
    await subject.flush();
    await store.clear();
    expect(store.topicFor('a', 'Garden'), isNull);
    subject.request('a', 'Garden');
    await subject.flush();
    expect(calls, hasLength(2));
    subject.dispose();
  });

  test('never labels its own hidden session', () async {
    final calls = <_Call>[];
    final subject = labeller(calls, (_) async => '{}');
    subject.request('hermes-android-chat-icons-20261030', 'Chat icons');
    await subject.flush();
    expect(calls, isEmpty);
    subject.dispose();
  });

  group('hidden labelling sessions', () {
    Session session(String id, {String? lineageRootId}) => Session(
      id: id,
      title: 'Labels',
      model: 'm',
      source: 'api_server',
      messageCount: 2,
      isActive: false,
      preview: '',
      startedAt: 0,
      lastActive: 0,
      lineageRootId: lineageRootId,
    );

    test('are recognised by id or by lineage', () {
      expect(
        session('hermes-android-chat-icons-20261030').isChatIconLabelling,
        isTrue,
      );
      expect(
        session(
          'compressed-tip',
          lineageRootId: 'hermes-android-chat-icons-20261029',
        ).isChatIconLabelling,
        isTrue,
      );
      expect(session('ordinary').isChatIconLabelling, isFalse);
    });

    test('are dropped from the gateway session list', () async {
      final client = ApiClient(
        baseUrl: 'http://gateway.test',
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'visible', 'title': 'Visible'},
                {'id': 'hermes-android-chat-icons-20261030', 'title': 'Icons'},
              ],
              'has_more': false,
            }),
            200,
          );
        }),
      );
      final sessions = await client.getSessions();
      expect(sessions.map((s) => s.id), ['visible']);
    });
  });

  test(
    'completeOnce posts one non-streaming turn to the named session',
    () async {
      late http.Request sent;
      final client = ApiClient(
        baseUrl: 'http://gateway.test',
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': '{"a":"yard"}'},
                },
              ],
            }),
            200,
          );
        }),
      );
      final answer = await client.completeOnce(
        sessionId: 'hermes-android-chat-icons-20261030',
        system: 'sys',
        user: 'usr',
      );
      expect(answer, '{"a":"yard"}');
      expect(sent.url.path, '/v1/chat/completions');
      expect(
        sent.headers['X-Hermes-Session-Id'],
        'hermes-android-chat-icons-20261030',
      );
      final body = jsonDecode(sent.body) as Map;
      expect(body['stream'], isFalse);
      expect(body['messages'], [
        {'role': 'system', 'content': 'sys'},
        {'role': 'user', 'content': 'usr'},
      ]);
    },
  );
}
