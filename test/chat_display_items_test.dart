import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/gateway_activity.dart';
import 'package:hermes_android/core/models/gateway_insight.dart';
import 'package:hermes_android/core/utils/chat_display_items.dart';

GatewayToolActivity _tool(String name) =>
    GatewayToolActivity(name: name, phase: GatewayToolActivityPhase.completed);

GatewaySubagentActivity _subagent(String id) => GatewaySubagentActivity(
  id: id,
  goal: 'goal $id',
  phase: GatewaySubagentPhase.completed,
);

const _notice = GatewayNotice(
  kind: GatewayNoticeKind.background,
  text: 'task done',
);

void main() {
  group('buildChatDisplayItems', () {
    test('keeps user and assistant prose in order with display content', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'user', 'content': 'question'},
          {'role': 'assistant', 'content': 'answer'},
        ],
      );

      expect(items, hasLength(2));
      final user = items[0] as Map<String, dynamic>;
      final assistant = items[1] as Map<String, dynamic>;
      expect(user['role'], 'user');
      expect(user['_display_content'], 'question');
      expect(assistant['role'], 'assistant');
      expect(assistant['_display_content'], 'answer');
    });

    test('normalizes persisted agent replies to assistant bubbles', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'user', 'content': 'question'},
          {'role': 'agent', 'content': 'answer'},
        ],
      );

      final reply = items.last as Map<String, dynamic>;
      expect(reply['role'], 'assistant');
      expect(reply['_display_content'], 'answer');
      expect(reply['_retry_prompt'], 'question');
    });

    test('tags each assistant reply with the last user prompt for retry', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'user', 'content': 'first'},
          {'role': 'assistant', 'content': 'reply one'},
          {'role': 'user', 'content': 'second'},
          {'role': 'assistant', 'content': 'reply two'},
        ],
      );

      expect((items[1] as Map<String, dynamic>)['_retry_prompt'], 'first');
      expect((items[3] as Map<String, dynamic>)['_retry_prompt'], 'second');
      expect(
        (items[0] as Map<String, dynamic>).containsKey('_retry_prompt'),
        isFalse,
      );
    });

    test('never attaches a retry prompt before the first user message', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'assistant', 'content': 'unsolicited'},
        ],
      );

      expect(
        (items.single as Map<String, dynamic>).containsKey('_retry_prompt'),
        isFalse,
      );
    });

    test('drops messages that are neither user nor assistant', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'system', 'content': 'you are Hermes'},
          {'role': 'assistant', 'content': 'answer'},
        ],
      );

      expect(items, hasLength(1));
      expect((items.single as Map<String, dynamic>)['role'], 'assistant');
    });

    test('drops messages with no text and no reasoning', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'assistant', 'content': ''},
          {'role': 'assistant', 'content': 'answer'},
        ],
      );

      expect(items, hasLength(1));
      expect(
        (items.single as Map<String, dynamic>)['_display_content'],
        'answer',
      );
    });

    test('folds a finished turn\'s stored tool call above its answer', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'user', 'content': 'run it'},
          {'role': 'tool', 'content': 'raw output'},
          {'role': 'assistant', 'content': 'done'},
        ],
        toolActivities: [_tool('terminal')],
      );

      expect(items, hasLength(3));
      expect(items[0], isA<Map<String, dynamic>>());
      final fold = items[1] as ChatTurnFold;
      expect(fold.unfolded, isFalse);
      expect(fold.stepCount, 1);
      expect((items[2] as Map<String, dynamic>)['_display_content'], 'done');
    });

    test('keeps consecutive tool results as rows in a turn with no answer', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'tool', 'content': 'first'},
          {'role': 'tool', 'content': 'second'},
        ],
        toolActivities: [_tool('read_file'), _tool('write_file')],
      );

      expect(items.map((item) => (item as ChatActivityStep).activity!.name), [
        'read_file',
        'write_file',
      ]);
    });

    test('a stored step keeps its row and its own time', () {
      final first = GatewayToolActivity.fromStoredResult(
        name: 'read_file',
        timestamp: 1792544523,
      );
      final second = GatewayToolActivity.fromStoredResult(
        name: 'terminal',
        timestamp: null,
      );
      final rows = [
        {'id': 41, 'role': 'tool', 'content': 'first', 'timestamp': 1792544523},
        {'id': 42, 'role': 'tool', 'content': 'second'},
      ];
      final items = buildChatDisplayItems(
        messages: rows,
        toolActivities: [first, second],
      ).cast<ChatActivityStep>();

      expect(items, hasLength(2));
      expect(items[0].activity, same(first));
      expect(items[0].storedRow, same(rows[0]));
      expect(items[0].activity!.startedAt, isNull);
      expect(items[1].activity!.lastActivityAt, isNull);
      expect(items[1].storedRow, same(rows[1]));
    });

    test(
      'suppresses a tool result bubble even without a matching activity',
      () {
        final items = buildChatDisplayItems(
          messages: [
            {'role': 'tool', 'content': 'orphan output'},
            {'role': 'assistant', 'content': 'done'},
          ],
        );

        expect(items, hasLength(1));
        expect(
          (items.single as Map<String, dynamic>)['_display_content'],
          'done',
        );
      },
    );

    test('appends an unanchored activity that never matched a stored row', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'assistant', 'content': 'streaming'},
        ],
        toolActivities: [_tool('search_files')],
      );

      expect(items, hasLength(2));
      expect(items[0], isA<Map<String, dynamic>>());
      expect((items[1] as ChatActivityStep).activity!.name, 'search_files');
    });

    test('leaves the caller list untouched while consuming activities', () {
      final activities = [_tool('terminal')];
      buildChatDisplayItems(
        messages: [
          {'role': 'tool', 'content': 'output'},
        ],
        toolActivities: activities,
      );

      expect(activities, hasLength(1));
    });

    // Pinned as-is, not endorsed: isToolResultMessage classifies on the whole
    // text, so an assistant reply that *embeds* a tool-result block is treated
    // as a tool result and its surrounding prose is dropped rather than
    // stripped. Phase 1.5 reworks message hierarchy; this test records what
    // ships today so that rework is a visible, deliberate change.
    test('drops assistant prose that embeds a raw tool result block', () {
      final items = buildChatDisplayItems(
        messages: [
          {
            'role': 'assistant',
            'content':
                'before <untrusted_tool_result id="1">noise</untrusted_tool_result>',
          },
        ],
        toolActivities: [_tool('terminal')],
      );

      expect(items, hasLength(1));
      expect((items.single as ChatActivityStep).activity!.name, 'terminal');
    });

    test(
      'strips a trailing tool result block when the role is not tool-like',
      () {
        final items = buildChatDisplayItems(
          messages: [
            {'role': 'assistant', 'content': 'plain answer'},
          ],
        );

        expect(
          (items.single as Map<String, dynamic>)['_display_content'],
          'plain answer',
        );
      },
    );

    test('folds a finished answer\'s reasoning above it', () {
      final messages = [
        {
          'role': 'assistant',
          'content': 'answer',
          '_gateway_reasoning': 'thinking hard',
        },
      ];
      final folded = buildChatDisplayItems(messages: messages);
      expect(folded, hasLength(2));
      expect(folded[0], isA<ChatTurnFold>());
      expect((folded[1] as Map<String, dynamic>)['_display_content'], 'answer');

      final unfolded = buildChatDisplayItems(
        messages: messages,
        foldChoice: (_) => true,
      );
      expect(unfolded, hasLength(3));
      final reasoning = unfolded[1] as ChatActivityStep;
      expect(reasoning.isReasoning, isTrue);
      expect(reasoning.reasoning, 'thinking hard');
      expect(reasoning.reasoningHeadline, 'thinking hard');
    });

    test('keeps reasoning visible when the message is still text-free', () {
      final items = buildChatDisplayItems(
        messages: [
          {
            'role': 'assistant',
            'content': '',
            '_gateway_reasoning': 'still thinking',
            '_gateway_pending_response': true,
          },
        ],
        turnActive: true,
      );

      expect(items, hasLength(1));
      final step = items.single as ChatActivityStep;
      expect(step.reasoning, 'still thinking');
      expect(step.isRunning, isTrue);
    });

    test('ignores reasoning attached to a user message', () {
      final items = buildChatDisplayItems(
        messages: [
          {
            'role': 'user',
            'content': 'question',
            '_gateway_reasoning': 'leaked',
          },
        ],
      );

      expect(items, hasLength(1));
      expect(items.single, isA<Map<String, dynamic>>());
    });

    test('puts a stored tool row before the next message\'s reasoning', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'tool', 'content': 'output'},
          {
            'role': 'assistant',
            'content': 'answer',
            '_gateway_reasoning': 'thinking',
          },
        ],
        toolActivities: [_tool('terminal')],
        foldChoice: (_) => true,
      );

      expect(items[0], isA<ChatTurnFold>());
      expect((items[1] as ChatActivityStep).activity!.name, 'terminal');
      expect((items[2] as ChatActivityStep).isReasoning, isTrue);
      expect(items[3], isA<Map<String, dynamic>>());
    });

    test('orders subagents after messages and notices last', () {
      final items = buildChatDisplayItems(
        messages: [
          {'role': 'assistant', 'content': 'answer'},
        ],
        subagentActivities: [_subagent('a1')],
        notices: [_notice],
      );

      expect(items, hasLength(3));
      expect(items[0], isA<Map<String, dynamic>>());
      expect((items[1] as List<GatewaySubagentActivity>).single.id, 'a1');
      expect((items[2] as GatewayNotice).text, 'task done');
    });

    test(
      'anchored notices land after their anchor message, not at the end',
      () {
        final items = buildChatDisplayItems(
          messages: [
            {'role': 'user', 'content': 'q1', 'id': 'u1'},
            {'role': 'assistant', 'content': 'a1', 'id': 'a1'},
            {'role': 'user', 'content': 'q2', 'id': 'u2'},
            {'role': 'assistant', 'content': 'a2', 'id': 'a2'},
          ],
          notices: [
            _notice.withAnchor('message:a1'),
            const GatewayNotice(kind: GatewayNoticeKind.review, text: 'later'),
          ],
        );

        expect(items, hasLength(6));
        expect((items[2] as GatewayNotice).text, 'task done');
        expect((items[3] as Map<String, dynamic>)['content'], 'q2');
        expect((items.last as GatewayNotice).text, 'later');
      },
    );

    test('returns nothing for an empty conversation', () {
      expect(buildChatDisplayItems(messages: const []), isEmpty);
    });
  });

  Map<String, dynamic> user(String text, {int? id, num? timestamp}) => {
    'role': 'user',
    'content': text,
    'id': ?id,
    'timestamp': ?timestamp,
  };
  Map<String, dynamic> assistant(String text, {int? id, num? timestamp}) => {
    'role': 'assistant',
    'content': text,
    'id': ?id,
    'timestamp': ?timestamp,
  };
  Map<String, dynamic> toolRow([int? id]) => {
    'role': 'tool',
    'content': 'output',
    'id': ?id,
  };
  GatewayToolActivity live(
    String name, {
    int? anchor,
    String? id,
    GatewayToolActivityPhase phase = GatewayToolActivityPhase.completed,
  }) => GatewayToolActivity(
    name: name,
    phase: phase,
    toolId: id,
    anchorMessageIndex: anchor,
  );

  /// A compact picture of the projection: `user:…`, `bot:…`, `fold`,
  /// `tool:<name>`, `reasoning`, `group:<name>x<count>`.
  List<String> shape(List<dynamic> items) => [
    for (final item in items)
      if (item is ChatTurnFold)
        item.unfolded ? 'fold:open' : 'fold'
      else if (item is ChatActivityGroupItem)
        'group:${item.toolName}x${item.steps.length}'
      else if (item is ChatActivityStep)
        item.isReasoning ? 'reasoning' : 'tool:${item.activity!.name}'
      else if (item is Map<String, dynamic>)
        '${item['role'] == 'user' ? 'user' : 'bot'}:${item['_display_content']}',
  ];

  group('turns (D1)', () {
    final finished = [
      user('go', id: 1),
      toolRow(2),
      toolRow(3),
      assistant('halfway', id: 4),
      toolRow(5),
      assistant('done', id: 6),
    ];
    final tools = [_tool('terminal'), _tool('terminal'), _tool('read_file')];

    test('a finished turn folds to one line above the final answer', () {
      final items = buildChatDisplayItems(
        messages: finished,
        toolActivities: tools,
      );
      expect(shape(items), ['user:go', 'fold', 'bot:done']);
      final fold = items[1] as ChatTurnFold;
      expect(fold.id, 'message:1');
      expect(fold.stepCount, 3);
    });

    test('an unfolded turn shows its steps in order, grouped', () {
      final items = buildChatDisplayItems(
        messages: finished,
        toolActivities: tools,
        foldChoice: (id) => id == 'message:1' ? true : null,
      );
      expect(shape(items), [
        'user:go',
        'fold:open',
        'group:terminalx2',
        'bot:halfway',
        'tool:read_file',
        'bot:done',
      ]);
    });

    test('a running turn shows every step ungrouped and no fold', () {
      final items = buildChatDisplayItems(
        messages: finished,
        toolActivities: tools,
        turnActive: true,
        foldChoice: (_) => true,
      );
      expect(shape(items), [
        'user:go',
        'tool:terminal',
        'tool:terminal',
        'bot:halfway',
        'tool:read_file',
        'bot:done',
      ]);
    });

    test('only the last turn is running', () {
      final items = buildChatDisplayItems(
        messages: [...finished, user('again', id: 7), toolRow(8)],
        toolActivities: [...tools, _tool('patch')],
        turnActive: true,
      );
      expect(shape(items), [
        'user:go',
        'fold',
        'bot:done',
        'user:again',
        'tool:patch',
      ]);
    });

    test('a turn that ended without a final answer stays unfolded', () {
      final items = buildChatDisplayItems(
        messages: [user('go'), toolRow(), assistant('halfway'), toolRow()],
        toolActivities: [_tool('terminal'), _tool('terminal')],
      );
      expect(shape(items), [
        'user:go',
        'tool:terminal',
        'bot:halfway',
        'tool:terminal',
      ]);
    });

    test('a sealed interim message is not a final answer', () {
      final items = buildChatDisplayItems(
        messages: [
          user('go'),
          toolRow(),
          {...assistant('halfway'), '_gateway_interim': true},
        ],
        toolActivities: [_tool('terminal')],
      );
      expect(shape(items), ['user:go', 'tool:terminal', 'bot:halfway']);
    });

    test('a plain reply has no fold line', () {
      final items = buildChatDisplayItems(
        messages: [user('hi'), assistant('hello')],
      );
      expect(shape(items), ['user:hi', 'bot:hello']);
    });

    test('interim messages alone do not fold', () {
      final items = buildChatDisplayItems(
        messages: [user('hi'), assistant('one moment'), assistant('hello')],
      );
      expect(shape(items), ['user:hi', 'bot:one moment', 'bot:hello']);
    });

    test('each turn folds on its own choice', () {
      final messages = [
        user('a', id: 1),
        toolRow(2),
        assistant('a done', id: 3),
        user('b', id: 4),
        toolRow(5),
        assistant('b done', id: 6),
      ];
      final items = buildChatDisplayItems(
        messages: messages,
        toolActivities: [_tool('terminal'), _tool('patch')],
        foldChoice: (id) => id == 'message:4' ? true : null,
      );
      expect(shape(items), [
        'user:a',
        'fold',
        'bot:a done',
        'user:b',
        'fold:open',
        'tool:patch',
        'bot:b done',
      ]);
    });

    test('a live turn is identified by its first tool call, then aliased', () {
      final liveTool = live('terminal', id: 'call-1', anchor: 0);
      final liveItems = buildChatDisplayItems(
        messages: [user('go'), assistant('done')],
        toolActivities: [liveTool],
      );
      final liveFold = liveItems.whereType<ChatTurnFold>().single;
      expect(liveFold.id, 'tool:call-1');
      expect(liveFold.aliases, isEmpty);

      // The server stores the turn: the user row id takes over, and a choice
      // made under the tool id still applies.
      final stored = buildChatDisplayItems(
        messages: [user('go', id: 9), toolRow(10), assistant('done', id: 11)],
        toolActivities: [
          GatewayToolActivity.fromStoredResult(
            name: 'terminal',
            toolId: 'call-1',
            timestamp: null,
          ),
        ],
        foldChoice: (id) => id == 'tool:call-1' ? true : null,
      );
      final storedFold = stored.whereType<ChatTurnFold>().single;
      expect(storedFold.id, 'message:9');
      expect(storedFold.aliases, ['tool:call-1']);
      expect(storedFold.unfolded, isTrue);
    });
  });

  group('live anchoring (D2)', () {
    test('text, tool, text keeps the tool between the two messages', () {
      final items = buildChatDisplayItems(
        messages: [user('go'), assistant('looking'), assistant('found it')],
        toolActivities: [live('terminal', anchor: 1)],
        turnActive: true,
      );
      expect(shape(items), [
        'user:go',
        'bot:looking',
        'tool:terminal',
        'bot:found it',
      ]);
    });

    test('a tool before any text sits above the text that follows', () {
      final items = buildChatDisplayItems(
        messages: [user('go'), assistant('found it')],
        toolActivities: [live('terminal', anchor: 0)],
        turnActive: true,
      );
      expect(shape(items), ['user:go', 'tool:terminal', 'bot:found it']);
    });

    test('two tools, an interim message, then a third tool', () {
      final items = buildChatDisplayItems(
        messages: [user('go'), assistant('halfway'), assistant('')],
        toolActivities: [
          live('terminal', anchor: 0),
          live('read_file', anchor: 0),
          live('patch', anchor: 1, phase: GatewayToolActivityPhase.running),
        ],
        turnActive: true,
      );
      expect(shape(items), [
        'user:go',
        'tool:terminal',
        'tool:read_file',
        'bot:halfway',
        'tool:patch',
      ]);
    });

    test('a live tool follows stored rows it started after', () {
      final items = buildChatDisplayItems(
        messages: [user('go'), toolRow(), assistant('next')],
        toolActivities: [_tool('terminal'), live('patch', anchor: 1)],
        turnActive: true,
      );
      expect(shape(items), [
        'user:go',
        'tool:terminal',
        'tool:patch',
        'bot:next',
      ]);
    });

    test('stored order takes over after a history refresh', () {
      // Live: both tools were anchored above the interim text by mistake of
      // timing. The stored rows say one ran after it.
      final liveItems = buildChatDisplayItems(
        messages: [user('go'), assistant('halfway'), assistant('done')],
        toolActivities: [
          live('terminal', anchor: 0, id: 'a'),
          live('patch', anchor: 0, id: 'b'),
        ],
        foldChoice: (_) => true,
      );
      expect(shape(liveItems), [
        'user:go',
        'fold:open',
        'tool:terminal',
        'tool:patch',
        'bot:halfway',
        'bot:done',
      ]);

      final stored = buildChatDisplayItems(
        messages: [
          user('go', id: 1),
          toolRow(2),
          assistant('halfway', id: 3),
          toolRow(4),
          assistant('done', id: 5),
        ],
        toolActivities: [
          GatewayToolActivity.fromStoredResult(
            name: 'terminal',
            toolId: 'a',
            timestamp: null,
          ),
          GatewayToolActivity.fromStoredResult(
            name: 'patch',
            toolId: 'b',
            timestamp: null,
          ),
        ],
        foldChoice: (_) => true,
      );
      expect(shape(stored), [
        'user:go',
        'fold:open',
        'tool:terminal',
        'bot:halfway',
        'tool:patch',
        'bot:done',
      ]);
    });

    test('merging a later event keeps the anchor', () {
      final started = live(
        'terminal',
        anchor: 3,
        phase: GatewayToolActivityPhase.running,
      );
      final done = started.merge(_tool('terminal'));
      expect(done.anchorMessageIndex, 3);
      expect(done.anchoredAt(5).anchorMessageIndex, 5);
      expect(done.anchoredAt(5).identity, started.identity);
    });
  });

  group('reasoning rows (D3)', () {
    test('uses the first line as the headline', () {
      expect(
        reasoningHeadlineOf('Checking the service binding\nThen the logs.'),
        'Checking the service binding',
      );
    });

    test('removes markdown emphasis and heading markers', () {
      expect(
        reasoningHeadlineOf('**Checking the `service` binding**\n\nmore'),
        'Checking the service binding',
      );
      expect(
        reasoningHeadlineOf('## _Plan_ for snake_case'),
        'Plan for snake_case',
      );
      expect(reasoningHeadlineOf('- first, look'), 'first, look');
    });

    test('skips leading blank lines', () {
      expect(reasoningHeadlineOf('\n  \nLook at the logs'), 'Look at the logs');
    });

    test('has no headline for empty or punctuation-only first lines', () {
      expect(reasoningHeadlineOf(''), isNull);
      expect(reasoningHeadlineOf('   \n\n'), isNull);
      expect(reasoningHeadlineOf('---\nReal text'), isNull);
      expect(reasoningHeadlineOf('**…**'), isNull);
    });

    test('cuts a very long first line', () {
      final headline = reasoningHeadlineOf('word ' * 100)!;
      expect(headline.length, lessThanOrEqualTo(160));
      expect(headline, endsWith('…'));
    });

    test('a reasoning row sits before its message and folds with the turn', () {
      final messages = [
        user('go'),
        toolRow(),
        {...assistant('done'), '_gateway_reasoning': 'Checking the binding'},
      ];
      final running = buildChatDisplayItems(
        messages: messages,
        toolActivities: [_tool('terminal')],
        turnActive: true,
      );
      expect(shape(running), [
        'user:go',
        'tool:terminal',
        'reasoning',
        'bot:done',
      ]);
      final finished = buildChatDisplayItems(
        messages: messages,
        toolActivities: [_tool('terminal')],
      );
      expect(shape(finished), ['user:go', 'fold', 'bot:done']);
      expect((finished[1] as ChatTurnFold).stepCount, 2);
    });
  });

  group('fold line (D4)', () {
    ChatTurnFold foldOf(
      List<Map<String, dynamic>> messages, {
      List<GatewayToolActivity>? tools,
    }) => buildChatDisplayItems(
      messages: messages,
      toolActivities: tools ?? [_tool('terminal')],
    ).whereType<ChatTurnFold>().single;

    test('duration comes from the stored timestamps', () {
      final fold = foldOf([
        user('go', timestamp: 1792544000),
        toolRow(),
        assistant('done', timestamp: 1792544144.5),
      ]);
      expect(fold.duration, const Duration(seconds: 144, milliseconds: 500));
    });

    test('duration comes from the observed turn times', () {
      final start = DateTime(2026, 11, 11, 15, 0, 0);
      final fold = foldOf([
        {...user('go'), '_turn_started_at': start},
        toolRow(),
        {
          ...assistant('done'),
          '_turn_ended_at': start.add(const Duration(seconds: 42)),
        },
      ]);
      expect(fold.duration, const Duration(seconds: 42));
    });

    test('states a step count when an end is missing', () {
      final noEnd = foldOf([
        user('go', timestamp: 1792544000),
        toolRow(),
        assistant('done'),
      ]);
      expect(noEnd.duration, isNull);
      expect(noEnd.stepCount, 1);

      final noStart = foldOf([
        user('go'),
        toolRow(),
        assistant('done', timestamp: 1792544000),
      ]);
      expect(noStart.duration, isNull);
    });

    test('ignores an end before the start', () {
      final fold = foldOf([
        user('go', timestamp: 1792544100),
        toolRow(),
        assistant('done', timestamp: 1792544000),
      ]);
      expect(fold.duration, isNull);
    });

    test('marks a turn with a failed step', () {
      final fold = foldOf(
        [user('go'), assistant('done')],
        tools: [
          live('terminal', anchor: 0),
          live('terminal', anchor: 0, phase: GatewayToolActivityPhase.failed),
        ],
      );
      expect(fold.hasFailure, isTrue);
      expect(fold.failureCount, 1);
      expect(fold.stepCount, 2);
      expect(
        foldOf([user('go'), toolRow(), assistant('done')]).hasFailure,
        isFalse,
      );
    });
  });

  group('grouping (D5)', () {
    ChatActivityStep step(
      String name, {
      GatewayToolActivityPhase phase = GatewayToolActivityPhase.completed,
    }) {
      final activity = GatewayToolActivity(name: name, phase: phase);
      return ChatActivityStep.tool(id: activity.identity, activity: activity);
    }

    const reasoning = ChatActivityStep.reasoning(id: 'r', reasoning: 'hm');

    test('a run of one tool becomes one group', () {
      final grouped = groupActivitySteps([
        step('terminal'),
        step('terminal'),
        step('terminal'),
      ]);
      final group = grouped.single as ChatActivityGroupItem;
      expect(group.toolName, 'terminal');
      expect(group.steps, hasLength(3));
      expect(group.activities, hasLength(3));
    });

    test('a single call is not a group', () {
      expect(
        groupActivitySteps([step('terminal')]).single,
        isA<ChatActivityStep>(),
      );
    });

    test('different tools, messages and reasoning end a run', () {
      final grouped = groupActivitySteps([
        step('terminal'),
        step('terminal'),
        step('read_file'),
        step('read_file'),
        {'role': 'assistant', '_display_content': 'text'},
        step('read_file'),
        reasoning,
        step('read_file'),
      ]);
      expect(shape(grouped), [
        'group:terminalx2',
        'group:read_filex2',
        'bot:text',
        'tool:read_file',
        'reasoning',
        'tool:read_file',
      ]);
    });

    test('reasoning rows are never grouped', () {
      final grouped = groupActivitySteps([reasoning, reasoning]);
      expect(grouped, hasLength(2));
      expect(grouped.every((item) => item is ChatActivityStep), isTrue);
    });

    test('a failure in the middle of a run keeps its own row', () {
      final failed = step('terminal', phase: GatewayToolActivityPhase.failed);
      final grouped = groupActivitySteps([
        step('terminal'),
        failed,
        step('terminal'),
      ]);
      expect(grouped, hasLength(3));
      expect(grouped[1], same(failed));
      expect(grouped.whereType<ChatActivityGroupItem>(), isEmpty);
    });

    test('a failure after a run leaves the run grouped', () {
      final grouped = groupActivitySteps([
        step('terminal'),
        step('terminal'),
        step('terminal', phase: GatewayToolActivityPhase.failed),
      ]);
      expect(shape(grouped), ['group:terminalx2', 'tool:terminal']);
    });

    test('a call that never finished is not grouped', () {
      final grouped = groupActivitySteps([
        step('terminal'),
        step('terminal', phase: GatewayToolActivityPhase.running),
      ]);
      expect(grouped.whereType<ChatActivityGroupItem>(), isEmpty);
    });

    test('a running turn is never grouped', () {
      final items = buildChatDisplayItems(
        messages: [user('go'), toolRow(), toolRow(), toolRow()],
        toolActivities: [
          _tool('terminal'),
          _tool('terminal'),
          _tool('terminal'),
        ],
        turnActive: true,
      );
      expect(items.whereType<ChatActivityGroupItem>(), isEmpty);
      expect(items.whereType<ChatActivityStep>(), hasLength(3));
    });
  });
}
