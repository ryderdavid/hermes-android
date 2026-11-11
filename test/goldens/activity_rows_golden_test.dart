import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/gateway_activity.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/utils/chat_display_items.dart';
import 'package:hermes_android/core/widgets/activity_detail_sheet.dart';
import 'package:hermes_android/core/widgets/activity_row.dart';
import 'package:hermes_android/core/widgets/turn_fold.dart';

import '../support/composer_harness.dart';
import 'golden_harness.dart';

/// One turn, shown running, folded and unfolded, plus both detail sheets.
/// The list is built by the real projection and drawn with the real rows.
final _at = DateTime(2026, 11, 11, 15, 50, 12);

GatewayToolActivity _tool(
  String name,
  String summary, {
  required int anchor,
  GatewayToolActivityPhase phase = GatewayToolActivityPhase.completed,
  double? secs,
  String? detail,
}) => GatewayToolActivity(
  name: name,
  phase: phase,
  summary: summary,
  detail: detail,
  durationSeconds: secs,
  lastActivityAt: _at,
  lastActivityTimeSource: GatewayToolTimeSource.observed,
  anchorMessageIndex: anchor,
);

const _ask =
    'The keyboard showed a warning that the return button stopped working. '
    'Can you find out why?';

const _midText =
    'Android currently shows the return-button service enabled and '
    'connected, with no crashed accessibility services.';

const _finalText =
    'The warning came from my profiling run: two test-harness crashes took '
    'the return-button service down briefly. It reconnected on its own and '
    'is healthy now.';

final _start = DateTime(2026, 11, 11, 15, 48);

List<Map<String, dynamic>> _messages({required bool finished}) => [
  {'role': 'user', 'content': _ask, '_turn_started_at': _start},
  {'role': 'assistant', 'content': _midText, '_gateway_interim': true},
  {
    'role': 'assistant',
    'content': finished ? _finalText : '',
    '_gateway_reasoning': 'Checking the service binding\nThen the crash log.',
    if (finished)
      '_turn_ended_at': _start.add(const Duration(minutes: 2, seconds: 24)),
  },
];

List<GatewayToolActivity> _activities({required bool finished}) => [
  _tool(
    'terminal',
    'checking whether the return-button service is connected',
    anchor: 0,
    secs: 1.8,
    detail: 'adb shell dumpsys accessibility | rg -A4 voicebar',
  ),
  _tool(
    'terminal',
    'reading recent crash logs for VoiceBar',
    anchor: 0,
    secs: 2.3,
    detail: 'adb logcat -b crash -d -t 200 | rg -i voicebar',
  ),
  _tool('read_file', 'app/src/main/AndroidManifest.xml', anchor: 1, secs: 0.2),
  _tool(
    'terminal',
    'looking for where swipe-to-send presses Send',
    anchor: 1,
    secs: 0.6,
    detail: "rg -n 'clickSend|returnTo|onClick' app/src/main/java",
  ),
  _tool(
    'terminal',
    'checking the current window state',
    anchor: 1,
    phase: finished
        ? GatewayToolActivityPhase.failed
        : GatewayToolActivityPhase.running,
    secs: finished ? 0.4 : null,
    detail: finished ? 'exit code 1: no devices/emulators found' : null,
  ),
];

class _Chat extends StatelessWidget {
  const _Chat({required this.finished, this.unfolded = false});

  final bool finished;
  final bool unfolded;

  @override
  Widget build(BuildContext context) {
    final messages = _messages(finished: finished);
    final items = buildChatDisplayItems(
      messages: messages,
      toolActivities: _activities(finished: finished),
      turnActive: !finished,
      foldChoice: (_) => unfolded,
    );
    final host = ComposerHost()..streaming = !finished;
    return Scaffold(
      appBar: AppBar(title: const Text('VoiceBar keyboard warning')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final item in items)
                  if (item is ChatTurnFold)
                    TurnFoldLine(
                      duration: item.duration,
                      stepCount: item.stepCount,
                      failureCount: item.failureCount,
                      unfolded: item.unfolded,
                      onTap: () {},
                    )
                  else if (item is ChatActivityGroupItem)
                    ActivityRow.group(
                      first: item.steps.first.activity!,
                      count: item.steps.length,
                      onTap: () => showActivityDetailSheet(
                        context,
                        group: item,
                        messages: messages,
                      ),
                    )
                  else if (item is ChatActivityStep)
                    item.isReasoning
                        ? ActivityRow.reasoning(
                            headline: item.reasoningHeadline,
                            running: item.isRunning,
                            onTap: () {},
                          )
                        : ActivityRow.tool(
                            activity: item.activity!,
                            onTap: () => showActivityDetailSheet(
                              context,
                              step: item,
                              messages: messages,
                            ),
                          )
                  else if (item is Map<String, dynamic>)
                    MessageBubble(
                      content: item['_display_content'] as String,
                      isUser: item['role'] == 'user',
                    ),
              ],
            ),
          ),
          host.build(),
        ],
      ),
    );
  }
}

void main() {
  for (final variant in goldenMatrix) {
    testWidgets('activity rows running ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        const _Chat(finished: false),
        variant: variant,
        settle: false,
      );
      await matchGolden(
        tester,
        'activity/activity_rows_running_${variant.name}.png',
      );
    });

    testWidgets('activity rows folded ${variant.name}', (tester) async {
      await pumpGolden(tester, const _Chat(finished: true), variant: variant);
      await matchGolden(
        tester,
        'activity/activity_rows_folded_${variant.name}.png',
      );
    });

    testWidgets('activity rows unfolded ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        const _Chat(finished: true, unfolded: true),
        variant: variant,
      );
      await matchGolden(
        tester,
        'activity/activity_rows_unfolded_${variant.name}.png',
      );
    });

    testWidgets('activity detail sheet ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        const _Chat(finished: true, unfolded: true),
        variant: variant,
      );
      // The command that ran on its own, between the file read and the
      // failure.
      await tester.tap(
        find.text('Looking for where swipe-to-send presses Send'),
      );
      await tester.pumpAndSettle();
      await matchGolden(
        tester,
        'activity/activity_detail_sheet_${variant.name}.png',
      );
    });

    testWidgets('activity group sheet ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        const _Chat(finished: true, unfolded: true),
        variant: variant,
      );
      await tester.tap(find.text('Ran 2 commands'));
      await tester.pumpAndSettle();
      await matchGolden(
        tester,
        'activity/activity_group_sheet_${variant.name}.png',
      );
    });
  }
}
