import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/gateway_activity.dart';
import 'package:hermes_android/core/utils/chat_display_items.dart';
import 'package:hermes_android/core/widgets/activity_detail_sheet.dart';
import 'package:hermes_android/core/widgets/markdown_code_block.dart';

import 'support/l10n_test_utils.dart';

ChatActivityStep _step(
  GatewayToolActivity activity, [
  Map<String, dynamic>? storedRow,
]) => ChatActivityStep.tool(
  id: activity.identity,
  activity: activity,
  storedRow: storedRow,
);

Future<void> _pump(WidgetTester tester, Widget sheet) async {
  await tester.pumpWidget(testAppWithL10n(Scaffold(body: sheet)));
  await tester.pump(const Duration(milliseconds: 300));
}

List<String> _codeBlocks(WidgetTester tester) => [
  for (final block in tester.widgetList<MarkdownCodeBlock>(
    find.byType(MarkdownCodeBlock),
  ))
    block.code,
];

void main() {
  group('ActivityCallDetail.resolve', () {
    test('a live call uses the fields it already has', () {
      final detail = ActivityCallDetail.resolve(
        _step(
          GatewayToolActivity(
            name: 'terminal',
            phase: GatewayToolActivityPhase.running,
            detail: 'adb logcat -b crash -d -t 200',
          ),
        ),
        const [],
      );
      expect(detail.command, 'adb logcat -b crash -d -t 200');
      expect(detail.arguments, isNull);
      expect(detail.detail, isNull);
      expect(detail.output, isNull);
    });

    test('a failed live call shows its error as detail, not as a command', () {
      final detail = ActivityCallDetail.resolve(
        _step(
          GatewayToolActivity(
            name: 'terminal',
            phase: GatewayToolActivityPhase.failed,
            detail: 'exit code 1',
          ),
        ),
        const [],
      );
      expect(detail.command, isNull);
      expect(detail.detail, 'exit code 1');
    });

    test('a stored call reads its arguments from the assistant tool call '
        'and its output from the stored row', () {
      final row = {
        'role': 'tool',
        'tool_call_id': 'call-1',
        'content': 'All tests passed!',
      };
      final detail = ActivityCallDetail.resolve(
        _step(
          GatewayToolActivity.fromStoredResult(
            name: 'terminal',
            toolId: 'call-1',
            timestamp: 1792544523,
          ),
          row,
        ),
        [
          {
            'role': 'assistant',
            'content': '',
            'tool_calls': [
              {
                'id': 'call-0',
                'function': {
                  'name': 'terminal',
                  'arguments': '{"command":"ls"}',
                },
              },
              {
                'id': 'call-1',
                'function': {
                  'name': 'terminal',
                  'arguments': jsonEncode({'command': 'flutter test'}),
                },
              },
            ],
          },
          row,
        ],
      );
      expect(detail.command, 'flutter test');
      expect(detail.output, 'All tests passed!');
      expect(detail.outputTruncated, isFalse);
    });

    test('arguments on the stored row are used when present', () {
      final detail = ActivityCallDetail.resolve(
        _step(
          GatewayToolActivity.fromStoredResult(name: 'read_file', timestamp: 1),
          {
            'role': 'tool',
            'content': 'file body',
            'args': {'path': 'lib/main.dart', 'api_key': 'sk-secret'},
          },
        ),
        const [],
      );
      expect(detail.command, isNull);
      final arguments = jsonDecode(detail.arguments!) as Map<String, dynamic>;
      expect(arguments['path'], 'lib/main.dart');
      // A secret-looking argument is never shown.
      expect(arguments['api_key'], '•••');
      expect(detail.arguments, isNot(contains('sk-secret')));
    });

    test('output is cut to 4 KB', () {
      final detail = ActivityCallDetail.resolve(
        _step(
          GatewayToolActivity.fromStoredResult(name: 'terminal', timestamp: 1),
          {'role': 'tool', 'content': 'x' * 5000},
        ),
        const [],
      );
      expect(detail.output, hasLength(kActivityOutputLimit));
      expect(kActivityOutputLimit, 4096);
      expect(detail.outputTruncated, isTrue);
    });

    test('an older stored call has nothing but its summary', () {
      final detail = ActivityCallDetail.resolve(
        _step(
          GatewayToolActivity.fromStoredResult(
            name: 'terminal',
            timestamp: null,
            contextPreview: 'flutter analyze',
          ),
          {'role': 'tool', 'content': ''},
        ),
        const [],
      );
      expect(detail.command, isNull);
      expect(detail.arguments, isNull);
      expect(detail.detail, isNull);
      expect(detail.output, isNull);
    });
  });

  group('ActivityDetailSheet', () {
    testWidgets('a live call shows state, duration, time, summary and '
        'command', (tester) async {
      final activity = GatewayToolActivity(
        name: 'terminal',
        phase: GatewayToolActivityPhase.completed,
        summary: 'reading recent crash logs',
        detail: 'adb logcat -b crash -d -t 200',
        durationSeconds: 2.3,
        lastActivityAt: DateTime(2026, 11, 11, 15, 50, 12),
        lastActivityTimeSource: GatewayToolTimeSource.observed,
      );
      await _pump(
        tester,
        ActivityDetailSheet.call(
          ActivityCallDetail.resolve(_step(activity), const []),
        ),
      );

      expect(find.text('Terminal'), findsOneWidget);
      expect(find.text('Completed in 2.3 s · 15:50:12'), findsOneWidget);
      expect(find.text('Reading recent crash logs'), findsOneWidget);
      expect(find.text('Command'), findsOneWidget);
      expect(_codeBlocks(tester), ['adb logcat -b crash -d -t 200']);
      // The command can be copied from its code block.
      expect(find.byTooltip('Copy code'), findsOneWidget);
      expect(find.text('Output'), findsNothing);
      expect(find.text('Arguments'), findsNothing);
    });

    testWidgets('a running call says so', (tester) async {
      await _pump(
        tester,
        ActivityDetailSheet.call(
          ActivityCallDetail(
            activity: GatewayToolActivity(
              name: 'terminal',
              phase: GatewayToolActivityPhase.running,
            ),
          ),
        ),
      );
      expect(find.text('Running'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a failed call says how long it ran before failing', (
      tester,
    ) async {
      await _pump(
        tester,
        ActivityDetailSheet.call(
          ActivityCallDetail(
            activity: GatewayToolActivity(
              name: 'terminal',
              phase: GatewayToolActivityPhase.failed,
              durationSeconds: 0.4,
            ),
            detail: 'exit code 1',
          ),
        ),
      );
      expect(find.text('Failed after 400 ms'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(_codeBlocks(tester), ['exit code 1']);
    });

    testWidgets('a stored call with detail shows command and an output '
        'excerpt', (tester) async {
      final activity = GatewayToolActivity.fromStoredResult(
        name: 'terminal',
        toolId: 'call-1',
        timestamp: 1792544523,
        args: {'command': 'flutter test'},
      );
      await _pump(
        tester,
        ActivityDetailSheet.call(
          ActivityCallDetail.resolve(
            _step(activity, {
              'role': 'tool',
              'content': 'y' * 5000,
              'args': {'command': 'flutter test'},
            }),
            const [],
          ),
        ),
      );

      expect(find.text('Command'), findsOneWidget);
      expect(find.text('Output'), findsOneWidget);
      expect(_codeBlocks(tester), ['flutter test', 'y' * 4096]);
      expect(find.text('Output truncated'), findsOneWidget);
      expect(find.byTooltip('Copy code'), findsNWidgets(2));
    });

    testWidgets('a stored call without detail shows summary, state and time '
        'only', (tester) async {
      final activity = GatewayToolActivity.fromStoredResult(
        name: 'terminal',
        timestamp: 1792544523,
        contextPreview: 'flutter analyze',
      );
      await _pump(
        tester,
        ActivityDetailSheet.call(
          ActivityCallDetail.resolve(
            _step(activity, {'role': 'tool', 'content': ''}),
            const [],
          ),
        ),
      );

      expect(find.text('Terminal'), findsOneWidget);
      expect(find.textContaining('Completed · '), findsOneWidget);
      expect(find.text('Checking the code for issues'), findsOneWidget);
      // No empty sections.
      expect(find.byType(MarkdownCodeBlock), findsNothing);
      for (final heading in ['Command', 'Arguments', 'Details', 'Output']) {
        expect(find.text(heading), findsNothing, reason: heading);
      }
    });

    testWidgets('a call with no time leaves the time out', (tester) async {
      await _pump(
        tester,
        ActivityDetailSheet.call(
          ActivityCallDetail(
            activity: GatewayToolActivity(
              name: 'skills_list',
              phase: GatewayToolActivityPhase.completed,
            ),
          ),
        ),
      );
      expect(find.text('Completed'), findsOneWidget);
      // With no summary, the title is not repeated as one.
      expect(find.text('Skills list'), findsOneWidget);
    });

    testWidgets('a group lists each call with its summary and command', (
      tester,
    ) async {
      GatewayToolActivity command(String summary, String cmd, double secs) =>
          GatewayToolActivity(
            name: 'terminal',
            phase: GatewayToolActivityPhase.completed,
            summary: summary,
            detail: cmd,
            durationSeconds: secs,
          );
      await _pump(
        tester,
        ActivityDetailSheet.group([
          for (final activity in [
            command('checking the service', 'adb shell dumpsys', 1.8),
            command('reading crash logs', 'adb logcat -b crash', 2.3),
            command('looking for the send button', 'rg -n clickSend', 0.6),
          ])
            ActivityCallDetail.resolve(_step(activity), const []),
        ]),
      );

      expect(find.text('Command executions'), findsOneWidget);
      expect(find.text('Checking the service'), findsOneWidget);
      expect(find.text('Reading crash logs'), findsOneWidget);
      expect(find.text('Looking for the send button'), findsOneWidget);
      expect(_codeBlocks(tester), [
        'adb shell dumpsys',
        'adb logcat -b crash',
        'rg -n clickSend',
      ]);
      expect(find.text('1.8 s'), findsOneWidget);
      expect(find.text('600 ms'), findsOneWidget);
    });

    testWidgets('a group of another tool is titled with the tool name', (
      tester,
    ) async {
      await _pump(
        tester,
        ActivityDetailSheet.group([
          for (final path in ['lib/a.dart', 'lib/b.dart'])
            ActivityCallDetail(
              activity: GatewayToolActivity(
                name: 'read_file',
                phase: GatewayToolActivityPhase.completed,
                summary: path,
              ),
            ),
        ]),
      );
      expect(find.text('Read file'), findsOneWidget);
      expect(find.text('Read file: lib/a.dart'), findsOneWidget);
      expect(find.byType(MarkdownCodeBlock), findsNothing);
    });

    testWidgets('reasoning shows the full text, selectable', (tester) async {
      const text = 'Checking the service binding\n\nThe log shows two crashes.';
      await _pump(tester, const ActivityDetailSheet.reasoning(text));

      expect(find.text('Reasoning'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SelectionArea),
          matching: find.text(text),
        ),
        findsOneWidget,
      );
    });

    testWidgets('showActivityDetailSheet opens the right layout', (
      tester,
    ) async {
      final step = _step(
        GatewayToolActivity(
          name: 'terminal',
          phase: GatewayToolActivityPhase.completed,
          summary: 'running the test suite',
        ),
      );
      await tester.pumpWidget(
        testAppWithL10n(
          Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showActivityDetailSheet(
                      context,
                      step: step,
                      messages: const [],
                    ),
                    child: const Text('one'),
                  ),
                  TextButton(
                    onPressed: () => showActivityDetailSheet(
                      context,
                      group: ChatActivityGroupItem(
                        id: 'g',
                        steps: [step, step],
                      ),
                      messages: const [],
                    ),
                    child: const Text('many'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      expect(find.text('Terminal'), findsOneWidget);
      expect(find.text('Running the test suite'), findsOneWidget);
      Navigator.of(tester.element(find.byType(ActivityDetailSheet))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('many'));
      await tester.pumpAndSettle();
      expect(find.text('Command executions'), findsOneWidget);
      expect(find.text('Running the test suite'), findsNWidgets(2));
    });
  });
}
