import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/agent_thread.dart';
import 'package:hermes_android/core/services/thread_wire.dart';
import 'package:hermes_android/core/utils/chat_display_items.dart';

final _t0 = DateTime.utc(2026, 11, 11, 14, 0);

double _secs(DateTime time) => time.millisecondsSinceEpoch / 1000;

AgentThread _thread(
  String id, {
  required DateTime? spawnedAt,
  AgentThreadState state = AgentThreadState.running,
}) => AgentThread(id: id, goal: 'Goal $id', state: state, spawnedAt: spawnedAt);

/// Three turns, one minute apart.
List<Map<String, dynamic>> _threeTurns() => [
  {
    'id': 1,
    'role': 'user',
    'content': 'Plan the release',
    'timestamp': _secs(_t0),
  },
  {'id': 2, 'role': 'assistant', 'content': 'On it.'},
  {
    'id': 3,
    'role': 'user',
    'content': 'Friday',
    'timestamp': _secs(_t0.add(const Duration(minutes: 1))),
  },
  {'id': 4, 'role': 'assistant', 'content': 'Friday it is.'},
  {
    'id': 5,
    'role': 'user',
    'content': 'Thanks',
    'timestamp': _secs(_t0.add(const Duration(minutes: 2))),
  },
  {'id': 6, 'role': 'assistant', 'content': 'Any time.'},
];

List<String> _shape(List<dynamic> items) => [
  for (final item in items)
    switch (item) {
      final ChatThreadsStartedItem started =>
        'started:${started.threads.map((t) => t.id).join(',')}',
      final ChatThreadReportItem report =>
        'report:${report.report.entries.map((e) => e.goal).join(',')}',
      final ChatThreadMessageItem message =>
        '${message.message.kind.name}:${message.message.text}'
            '${message.stored ? '' : ' (live)'}',
      final Map<String, dynamic> bubble =>
        '${bubble['role']}:${bubble['_display_content']}',
      _ => item.runtimeType.toString(),
    },
];

void main() {
  group('Started N threads card', () {
    test('one card lists every thread a single turn started', () {
      final at = _t0.add(const Duration(seconds: 20));
      final items = buildChatDisplayItems(
        messages: _threeTurns(),
        threads: [
          _thread('a', spawnedAt: at),
          _thread('b', spawnedAt: at.add(const Duration(seconds: 1))),
          _thread('c', spawnedAt: at.add(const Duration(seconds: 2))),
        ],
      );

      expect(_shape(items), [
        'user:Plan the release',
        'assistant:On it.',
        'started:a,b,c',
        'user:Friday',
        'assistant:Friday it is.',
        'user:Thanks',
        'assistant:Any time.',
      ]);
    });

    test('threads of different turns get their own cards', () {
      final items = buildChatDisplayItems(
        messages: _threeTurns(),
        threads: [
          _thread('a', spawnedAt: _t0.add(const Duration(seconds: 5))),
          _thread('b', spawnedAt: _t0.add(const Duration(seconds: 70))),
        ],
      );

      expect(_shape(items), [
        'user:Plan the release',
        'assistant:On it.',
        'started:a',
        'user:Friday',
        'assistant:Friday it is.',
        'started:b',
        'user:Thanks',
        'assistant:Any time.',
      ]);
    });

    test('the card carries the thread objects, so rows show their state', () {
      final items = buildChatDisplayItems(
        messages: _threeTurns(),
        threads: [
          _thread(
            'a',
            spawnedAt: _t0.add(const Duration(seconds: 5)),
            state: AgentThreadState.needsYou,
          ),
        ],
      );

      final card = items.whereType<ChatThreadsStartedItem>().single;
      expect(card.threads.single.state, AgentThreadState.needsYou);
      expect(card.id, 'threads-started:a');
    });

    test('a running turn still shows its card, after the steps so far', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'user', 'content': 'Go', '_turn_started_at': _t0},
          {'role': 'assistant', 'content': 'Splitting this up'},
        ],
        threads: [_thread('a', spawnedAt: _t0.add(const Duration(seconds: 3)))],
        turnActive: true,
      );

      expect(_shape(items), [
        'user:Go',
        'assistant:Splitting this up',
        'started:a',
      ]);
    });

    test('a thread with no turn to match goes with the last turn', () {
      final items = buildChatDisplayItems(
        messages: _threeTurns(),
        threads: [
          // Started before the loaded history begins.
          _thread('early', spawnedAt: _t0.subtract(const Duration(hours: 1))),
        ],
      );

      expect(_shape(items).last, 'started:early');
    });

    test('no threads, no card', () {
      final items = buildChatDisplayItems(messages: _threeTurns());
      expect(items.whereType<ChatThreadsStartedItem>(), isEmpty);
    });
  });

  group('thread report card', () {
    const report = '''
[ASYNC DELEGATION COMPLETE — deleg_1]
A background subagent you dispatched earlier has finished.

Original goal: Draft release notes
Status: completed   Duration: 240.0s
--- RESULT ---
Drafted the notes.''';

    test('replaces the raw task-source text; the reply stays a message', () {
      final items = buildChatDisplayItems(
        messages: [
          {'id': 1, 'role': 'user', 'content': 'Friday'},
          {'id': 2, 'role': 'assistant', 'content': 'Friday it is.'},
          {
            'id': 3,
            'role': 'user',
            'content': report,
            'display_kind': 'async_delegation_complete',
          },
          {'id': 4, 'role': 'assistant', 'content': 'The notes are drafted.'},
        ],
      );

      expect(_shape(items), [
        'user:Friday',
        'assistant:Friday it is.',
        'report:Draft release notes',
        'assistant:The notes are drafted.',
      ]);
      final card = items.whereType<ChatThreadReportItem>().single;
      expect(card.id, 'thread-report:message:3');
      expect(card.report.entries.single.summary, 'Drafted the notes.');
      // The coordinator's reply to a report has no user prompt to retry.
      final reply = items.last as Map<String, dynamic>;
      expect(reply.containsKey('_retry_prompt'), isFalse);
    });

    test('a person quoting a report keeps their bubble', () {
      final items = buildChatDisplayItems(
        messages: [
          {'id': 1, 'role': 'user', 'content': 'What is this?\n$report'},
        ],
      );

      expect(items.whereType<ChatThreadReportItem>(), isEmpty);
      expect((items.single as Map<String, dynamic>)['role'], 'user');
    });
  });

  group('thread message cards', () {
    const update = '''
[THREAD UPDATE — sa-1]
A background thread you started sent an interim update.
Thread task: Check CI matrix
--- UPDATE ---
2 of 5 jobs fail.''';

    test('an update turn becomes a card', () {
      final items = buildChatDisplayItems(
        messages: [
          {
            'id': 7,
            'role': 'user',
            'content': update,
            'display_kind': 'async_delegation_message',
          },
          {'id': 8, 'role': 'assistant', 'content': 'CI has two failures.'},
        ],
      );

      expect(_shape(items), [
        'update:2 of 5 jobs fail.',
        'assistant:CI has two failures.',
      ]);
    });

    test('the server annotation wins over the scaffold text', () {
      final items = buildChatDisplayItems(
        messages: [
          {
            'id': 7,
            'role': 'user',
            'content': update,
            'display_kind': 'async_delegation_message',
            'display_metadata': {
              'type': 'async_delegation_message',
              'message_id': 'dmsg_1',
              'kind': 'update',
              'text': 'From the annotation.',
              'subagent_id': 'sa-1',
              'goal': 'Check CI matrix',
            },
          },
        ],
      );

      final card = items.whereType<ChatThreadMessageItem>().single;
      expect(card.message.text, 'From the annotation.');
      expect(card.message.messageId, 'dmsg_1');
    });

    test('a live message shows until the history has it, then once', () {
      final live = ThreadMessageAnnotation.parse({
        'type': 'async_delegation_message',
        'message_id': 'dmsg_1',
        'kind': 'update',
        'text': '2 of 5 jobs fail.',
        'subagent_id': 'sa-1',
        'goal': 'Check CI matrix',
      })!;

      final before = buildChatDisplayItems(
        messages: [
          {'id': 1, 'role': 'user', 'content': 'Friday'},
          {'id': 2, 'role': 'assistant', 'content': 'Friday it is.'},
        ],
        liveThreadMessages: [live],
      );
      expect(_shape(before).last, 'update:2 of 5 jobs fail. (live)');

      final after = buildChatDisplayItems(
        messages: [
          {'id': 1, 'role': 'user', 'content': 'Friday'},
          {'id': 2, 'role': 'assistant', 'content': 'Friday it is.'},
          {'id': 7, 'role': 'user', 'content': update},
        ],
        liveThreadMessages: [live],
      );
      expect(_shape(after), [
        'user:Friday',
        'assistant:Friday it is.',
        'update:2 of 5 jobs fail.',
      ]);
    });

    test('a live question is matched to its stored turn by question id', () {
      final live = ThreadMessageAnnotation.parse({
        'type': 'async_delegation_message',
        'message_id': 'dmsg_2',
        'kind': 'question',
        'text': 'Drop them?',
        'subagent_id': 'sa-1',
        'question_id': 'q_1',
      })!;
      final items = buildChatDisplayItems(
        messages: [
          {
            'id': 9,
            'role': 'user',
            'content':
                '[THREAD QUESTION — sa-1, question q_1]\n'
                'Thread task: Audit\n--- QUESTION ---\nDrop them, or flag?',
          },
        ],
        liveThreadMessages: [live],
      );

      expect(items.whereType<ChatThreadMessageItem>(), hasLength(1));
    });
  });
}
