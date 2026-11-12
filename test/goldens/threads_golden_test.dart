import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/chat_icons/chat_mark.dart';
import 'package:hermes_android/core/expressive/shapes.dart';
import 'package:hermes_android/core/models/gateway_approval.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/screens/thread_screen.dart';
import 'package:hermes_android/core/services/agent_threads_controller.dart';
import 'package:hermes_android/core/services/thread_wire.dart';
import 'package:hermes_android/core/widgets/chat_context_header.dart';
import 'package:hermes_android/core/widgets/gateway_approval_dialog.dart';
import 'package:hermes_android/core/widgets/thread_cards.dart';
import 'package:hermes_android/core/widgets/threads_sheet.dart';
import 'package:hermes_android/core/widgets/threads_strip.dart';

import '../support/composer_harness.dart';
import '../support/fake_threads_gateway.dart';
import 'golden_harness.dart';

/// The coordinator-threads surfaces, drawn with the real widgets over the
/// same chat chrome `ChatScreen` builds. Thread data and the clock are fixed.
final _now = DateTime.utc(2026, 11, 11, 14, 34);
double _ago(Duration age) => _now.subtract(age).millisecondsSinceEpoch / 1000;

const _licences = 'Audit dependency licences';
const _notes = 'Draft release notes';
const _ci = 'Check CI matrix';

const _ask =
    'Plan the 3.2 release: audit our dependency licences, draft the release '
    'notes, and check the CI matrix.';

/// Three threads: one waiting on the user, one done, one running.
AgentThreadsController _controller({FakeThreadsGateway? gateway}) {
  final fake = gateway ?? FakeThreadsGateway(support: ThreadSupport.full);
  fake
    ..roster = ThreadRosterSnapshot(
      threads: [
        rosterRow(
          'licences',
          goal: _licences,
          tools: 7,
          model: 'claude-sonnet-5-5',
          startedAt: _ago(const Duration(minutes: 2)),
          question: {
            'question_id': 'q1',
            'text': 'Drop the two AGPL packages, or flag them for legal?',
          },
        ),
        rosterRow(
          'notes',
          goal: _notes,
          tools: 12,
          startedAt: _ago(const Duration(minutes: 4)),
        ),
        rosterRow(
          'ci',
          goal: _ci,
          tools: 3,
          model: 'claude-sonnet-5-5',
          startedAt: _ago(const Duration(minutes: 1)),
        ),
      ],
    )
    ..status = const DelegationStatusSnapshot(
      activeCount: 2,
      paused: false,
      maxConcurrent: 3,
      model: 'claude-sonnet-5-5',
    );
  final controller = AgentThreadsController(gateway: fake, clock: () => _now);
  addTearDown(controller.dispose);
  return controller;
}

Future<AgentThreadsController> _seeded({FakeThreadsGateway? gateway}) async {
  final controller = _controller(gateway: gateway);
  await controller.seed();
  controller.applyEvent(ThreadEventType.complete, {
    'subagent_id': 'notes',
    'goal': _notes,
    'status': 'completed',
    'tool_count': 12,
    'duration_seconds': 240.0,
  });
  return controller;
}

PreferredSizeWidget _chatBar(BuildContext context, {bool coordinator = true}) {
  final theme = Theme.of(context);
  const title = 'Release 3.2 planning';
  return AppBar(
    centerTitle: false,
    titleSpacing: 0,
    title: Row(
      children: [
        ChatMark(
          sessionId: 'mock',
          title: title,
          letterStyle: MarkStyle.forKey('hermes-android'),
          letterLabel: 'hermes-android',
          size: 40,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (coordinator)
                Row(
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Coordinator',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(48),
      child: ChatContextHeader(
        projectName: 'hermes-android',
        model: 'claude-opus-5-5',
        reasoningEffort: 'high',
        connectionLabel: 'Mac Studio',
        connectionStatus: ChatConnectionStatus.connected,
      ),
    ),
    actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert))],
  );
}

Widget _user(String text) => MessageBubble(content: text, isUser: true);
Widget _bot(String text) => MessageBubble(content: text, isUser: false);

class _Chat extends StatelessWidget {
  const _Chat({required this.controller, required this.body});

  final AgentThreadsController controller;
  final List<Widget> Function(BuildContext context) body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _chatBar(context),
      body: Column(
        children: [
          ThreadsStrip(
            threads: controller.threads,
            paused: controller.paused,
            onOpenThread: (_) {},
            onShowAll: () => showThreadsSheet(
              context,
              controller: controller,
              onOpenThread: (_) {},
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: body(context),
            ),
          ),
          ComposerHost().build(),
        ],
      ),
    );
  }
}

List<Widget> _coordinatorTurn(AgentThreadsController controller) => [
  _user(_ask),
  _bot(
    "On it. I've split this into three threads so we can keep talking "
    'while they work. What date are you aiming to publish?',
  ),
  ThreadsStartedCard(
    threads: controller.threadsInStartOrder,
    now: _now,
    onOpenThread: (_) {},
  ),
  _user('Friday, and skip the Office preview work.'),
  _bot(
    "Friday it is. I've told the release-notes thread to leave the Office "
    'previews out.',
  ),
];

/// Lets the widget under test go before the binding checks for timers.
Future<void> _dispose(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

Future<void> _frames(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final variant in goldenMatrix) {
    testWidgets('threads strip ${variant.name}', (tester) async {
      final controller = await _seeded();
      await pumpGolden(
        tester,
        _Chat(
          controller: controller,
          body: (_) => _coordinatorTurn(controller),
        ),
        variant: variant,
        settle: false,
      );
      await matchGolden(tester, 'threads/threads_strip_${variant.name}.png');
    });

    testWidgets('threads sheet ${variant.name}', (tester) async {
      final controller = await _seeded();
      await pumpGolden(
        tester,
        _Chat(
          controller: controller,
          body: (_) => _coordinatorTurn(controller),
        ),
        variant: variant,
        settle: false,
      );
      await tester.tap(find.byKey(const Key('threads-strip-all')));
      await _frames(tester);
      await tester.tap(find.byKey(const Key('threads-earlier')));
      await _frames(tester);
      await matchGolden(tester, 'threads/threads_sheet_${variant.name}.png');
    });

    testWidgets('thread view ${variant.name}', (tester) async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full)
        ..tailSnapshot = const ThreadTailSnapshot(
          available: true,
          text: '''
14:32:01 user     | kickoff: List every runtime dependency with its licence. Flag anything copyleft. Exclude dev-only packages.
14:32:02 start    | Audit dependency licences
14:32:05 tool     | -> terminal({"command": "flutter pub deps --json"})
14:32:08 result   | terminal ok 3.1s: {"packages": []}
14:32:09 tool     | -> read_file({"path": "pubspec.lock"})
14:32:09 result   | read_file ok 0.2s: sdks:
14:32:12 tool     | -> web_search({"query": "pdfx_core licence"})
14:32:14 result   | web_search ok 2.4s: AGPL-3.0
14:32:20 assistant| 41 of 48 runtime packages are MIT/BSD/Apache. Two are AGPL-3.0; checking whether either ships in the release APK.
14:32:21 tool     | -> terminal({"command": "rg -l AGPL ~/.pub-cache"})
''',
        );
      final controller = await _seeded(gateway: gateway);
      // Answered: the thread runs again and takes steering.
      controller.applyEvent(ThreadEventType.question, {
        'subagent_id': 'licences',
        'question_id': 'q1',
        'status': 'answered',
        'answered_by': 'user',
        'answer': 'Flag them for legal',
      });
      await pumpGolden(
        tester,
        ThreadScreen(
          threads: controller,
          threadId: 'licences',
          chatTitle: 'Release 3.2 planning',
          loadHistory: null,
        ),
        variant: variant,
        settle: false,
      );
      await tester.enterText(
        find.byKey(const Key('thread-steer-field')),
        'Skip dev-only dependencies',
      );
      await _frames(tester);
      await matchGolden(tester, 'threads/thread_view_${variant.name}.png');
      await _dispose(tester);
    });

    testWidgets('thread report card ${variant.name}', (tester) async {
      final controller = await _seeded();
      await pumpGolden(
        tester,
        _Chat(
          controller: controller,
          body: (_) => [
            _user('Friday, and skip the Office preview work.'),
            _bot("Friday it is. I've told the release-notes thread."),
            ThreadReportCard(
              report: const ThreadReportAnnotation(
                delegationId: 'deleg_1',
                entries: [
                  ThreadReportEntry(
                    subagentId: 'notes',
                    goal: _notes,
                    status: 'completed',
                    toolCount: 12,
                    durationSeconds: 240,
                    summary:
                        'Drafted docs/releases/v3.2.0-you.1.md: 9 user-facing '
                        'changes grouped under Chat, Settings and '
                        'Notifications. Two items need a screenshot before '
                        'publishing.',
                  ),
                ],
              ),
              onOpenThread: (_) {},
              onContinue: (_) {},
            ),
            _bot(
              'The release notes are drafted. Two entries need screenshots; '
              'I can capture them from the emulator once the CI thread '
              'finishes.',
            ),
            const ThreadReportCard(
              report: ThreadReportAnnotation(
                entries: [
                  ThreadReportEntry(
                    goal: _ci,
                    status: 'error',
                    toolCount: 3,
                    durationSeconds: 61,
                    summary: 'gh is not installed on the runner.',
                  ),
                ],
              ),
            ),
          ],
        ),
        variant: variant,
        settle: false,
      );
      await matchGolden(
        tester,
        'threads/thread_report_card_${variant.name}.png',
      );
    });

    testWidgets('thread message card ${variant.name}', (tester) async {
      final controller = await _seeded();
      const question = ThreadMessageAnnotation(
        messageId: 'dmsg_2',
        kind: ThreadMessageKind.question,
        subagentId: 'licences',
        goal: _licences,
        questionId: 'q1',
        text:
            'Two transitive packages are AGPL-3.0 (pdfx_core, ffmpeg_lite). '
            'Should I drop them from the release build or flag them for '
            'legal?',
      );
      await pumpGolden(
        tester,
        _Chat(
          controller: controller,
          body: (_) => [
            _bot(
              "Friday it is. I've told the release-notes thread to leave "
              'the Office previews out.',
            ),
            ThreadMessageCard(
              message: const ThreadMessageAnnotation(
                messageId: 'dmsg_1',
                kind: ThreadMessageKind.update,
                subagentId: 'ci',
                goal: _ci,
                text:
                    '2 of 5 jobs fail on Android API 35: golden drift in '
                    'settings_dark_blue. Still checking the other three.',
              ),
              onOpenThread: () {},
            ),
            ThreadMessageCard(
              message: question,
              question: controller.questionRecord('licences', 'q1'),
              onOpenThread: () {},
              onReply: (_) {},
              onLetCoordinatorDecide: () {},
            ),
            const ThreadMessageCard(
              message: ThreadMessageAnnotation(
                messageId: 'dmsg_0',
                kind: ThreadMessageKind.question,
                subagentId: 'notes',
                goal: _notes,
                questionId: 'q0',
                text: 'Include the Office preview work?',
              ),
              question: ThreadQuestionRecord(
                subagentId: 'notes',
                state: ThreadQuestionState.answered,
                answer: 'No, leave it out.',
                answeredBy: ThreadAnsweredBy.user,
              ),
            ),
          ],
        ),
        variant: variant,
        settle: false,
      );
      await matchGolden(
        tester,
        'threads/thread_message_card_${variant.name}.png',
      );
    });

    testWidgets('approval sheet raised by a thread ${variant.name}', (
      tester,
    ) async {
      final controller = await _seeded();
      await pumpGolden(
        tester,
        _Chat(
          controller: controller,
          body: (context) => [
            ..._coordinatorTurn(controller),
            Center(
              child: TextButton(
                onPressed: () => GatewayApprovalDialog.show(
                  context,
                  request: GatewayApprovalRequest.fromEventData({
                    'description': 'Re-run the failing Android jobs.',
                    'command': 'gh run rerun 18734 --failed',
                    'choices': ['once', 'session', 'always', 'deny'],
                    'subagent_id': 'ci',
                    'goal': _ci,
                  }),
                  onRespond: (_) async {},
                ),
                child: const SizedBox(key: Key('open'), width: 8, height: 8),
              ),
            ),
          ],
        ),
        variant: variant,
        settle: false,
      );
      await tester.tap(find.byKey(const Key('open')), warnIfMissed: false);
      await _frames(tester);
      await _frames(tester);
      await matchGolden(
        tester,
        'screens/approval_sheet_thread_${variant.name}.png',
      );
    });
  }
}
