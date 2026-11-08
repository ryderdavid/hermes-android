import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/gateway_activity.dart';
import 'package:hermes_android/core/widgets/gateway_activity_card.dart';
import 'package:hermes_android/l10n/app_localizations.dart';

void main() {
  group('GatewayToolActivity', () {
    test('parses the official tool.start contract', () {
      final activity = GatewayToolActivity.fromGatewayEvent('tool.start', {
        'tool_id': 'tool-1',
        'name': 'search_files',
        'context': 'Hermes Android workspace',
        'args_text': '{"query":"not rendered"}',
      });

      expect(activity, isNotNull);
      expect(activity!.toolId, 'tool-1');
      expect(activity.name, 'search_files');
      expect(activity.displayName, 'Search files');
      expect(activity.phase, GatewayToolActivityPhase.running);
      expect(activity.detail, 'Hermes Android workspace');
      // `context` is the detail line, not the title summary — no duplication.
      expect(activity.summary, isNull);
      expect(activity.displayTitle, 'Search files');
    });

    test('phrases a semantic summary from the shipped tool args', () {
      final activity = GatewayToolActivity.fromGatewayEvent('tool.start', {
        'tool_id': 'tool-9',
        'name': 'read_file',
        'args': {'path': '/Users/ryder/Code/hermes-android/lib/main.dart'},
      });

      expect(
        activity!.summary,
        '/Users/ryder/Code/hermes-android/lib/main.dart',
      );
      expect(
        activity.displayTitle,
        'Read file: /Users/ryder/Code/hermes-android/lib/main.dart',
      );
    });

    test('uses the redacted REST label preview when no args are shipped', () {
      final running = GatewayToolActivity.fromGatewayEvent('tool.start', {
        'tool': 'terminal',
        'toolCallId': 'call-1',
        'label': 'flutter analyze',
        'status': 'running',
      });
      expect(running!.name, 'terminal');
      expect(running.summary, 'checking the code for issues');
      expect(running.displayTitle, 'Terminal: checking the code for issues');

      // A label that is just the tool name adds nothing.
      final bare = GatewayToolActivity.fromGatewayEvent('tool.start', {
        'tool': 'terminal',
        'toolCallId': 'call-2',
        'label': 'terminal',
        'status': 'running',
      });
      expect(bare!.summary, isNull);
      expect(bare.displayTitle, 'Terminal');
    });

    test('merge keeps the start summary when progress carries no args', () {
      final start = GatewayToolActivity.fromGatewayEvent('tool.start', {
        'tool_id': 'tool-1',
        'name': 'terminal',
        'args': {'command': 'flutter test'},
      })!;
      final progress = GatewayToolActivity.fromGatewayEvent('tool.progress', {
        'tool_id': 'tool-1',
        'name': 'terminal',
        'preview': '42 tests passed',
      })!;

      final merged = start.merge(progress);
      expect(merged.summary, 'running the test suite');
      expect(merged.displayTitle, 'Terminal: running the test suite');
      expect(merged.detail, '42 tests passed');
    });

    test('parses progress without inventing an id', () {
      final activity = GatewayToolActivity.fromGatewayEvent('tool.progress', {
        'name': 'search_files',
        'preview': 'Scanning gateway event handlers',
      });

      expect(activity!.toolId, isNull);
      expect(activity.phase, GatewayToolActivityPhase.progress);
      expect(activity.detail, 'Scanning gateway event handlers');
    });

    test('parses a successful official tool.complete', () {
      final activity = GatewayToolActivity.fromGatewayEvent('tool.complete', {
        'tool_id': 'tool-1',
        'name': 'search_files',
        'summary': 'Found the official activity contract',
        'duration_s': 0.42,
        'result_text': 'Large result is intentionally not surfaced',
      });

      expect(activity!.phase, GatewayToolActivityPhase.completed);
      expect(activity.detail, 'Found the official activity contract');
      expect(activity.statusLabel, 'Completed in 420 ms');
    });

    test('uses the error as the safe failure summary', () {
      final activity = GatewayToolActivity.fromGatewayEvent('tool.complete', {
        'tool_id': 'tool-2',
        'name': 'terminal',
        'error': 'Synthetic command failed',
        'summary': 'This must not hide the error',
      });

      expect(activity!.phase, GatewayToolActivityPhase.failed);
      expect(activity.detail, 'Synthetic command failed');
      expect(activity.statusLabel, 'Failed');
    });

    test('keeps compatibility with legacy REST progress fields', () {
      final activity = GatewayToolActivity.fromGatewayEvent('tool.start', {
        'toolCallId': 'legacy-1',
        'tool': 'browser',
        'status': 'completed',
        'emoji': '🌐',
      });

      expect(activity!.toolId, 'legacy-1');
      expect(activity.phase, GatewayToolActivityPhase.completed);
      expect(activity.emoji, '🌐');
    });

    test('merges id-less progress into the official start state', () {
      final start = GatewayToolActivity.fromGatewayEvent('tool.start', {
        'tool_id': 'tool-1',
        'name': 'search_files',
        'context': 'Initial context',
      })!;
      final progress = GatewayToolActivity.fromGatewayEvent('tool.progress', {
        'name': 'search_files',
        'preview': 'Halfway through',
      })!;

      final merged = start.merge(progress);
      expect(merged.toolId, 'tool-1');
      expect(merged.phase, GatewayToolActivityPhase.progress);
      expect(merged.detail, 'Halfway through');
    });

    test(
      'preserves observed start and advances last activity on every event',
      () {
        final startTime = DateTime.utc(2026, 10, 21, 1, 2, 3);
        final progressTime = startTime.add(const Duration(seconds: 4));
        final completeTime = startTime.add(const Duration(seconds: 9));
        final start = GatewayToolActivity.fromGatewayEvent('tool.start', {
          'tool_id': 'call-1',
          'name': 'terminal',
        }, observedAt: startTime)!;
        final progress = GatewayToolActivity.fromGatewayEvent('tool.progress', {
          'tool_id': 'call-1',
          'name': 'terminal',
        }, observedAt: progressTime)!;
        final complete = GatewayToolActivity.fromGatewayEvent('tool.complete', {
          'tool_id': 'call-1',
          'name': 'terminal',
        }, observedAt: completeTime)!;
        final merged = start.merge(progress).merge(complete);
        expect(merged.identity, start.identity);
        expect(merged.startedAt, startTime);
        expect(merged.lastActivityAt, completeTime);
        expect(merged.lastActivityTimeSource, GatewayToolTimeSource.observed);
        expect(start.lastActivityAt, startTime);
        expect(start.merge(progress).lastActivityAt, progressTime);
      },
    );

    test('first progress or completion does not invent a start time', () {
      final observed = DateTime.utc(2026, 10, 21, 1, 2, 3);
      for (final event in ['tool.progress', 'tool.complete']) {
        final activity = GatewayToolActivity.fromGatewayEvent(event, {
          'name': 'terminal',
        }, observedAt: observed)!;
        expect(activity.startedAt, isNull);
        expect(activity.lastActivityAt, observed);
      }
      expect(
        GatewayToolActivity.fromGatewayEvent('tool.start', {
          'name': 'terminal',
        })!.lastActivityAt,
        isNull,
      );
    });

    test('stored result uses numeric Unix seconds, never fetch time', () {
      final result = GatewayToolActivity.fromStoredResult(
        name: 'terminal',
        timestamp: 1792544523.125,
      );
      expect(result.startedAt, isNull);
      expect(
        result.lastActivityAt,
        DateTime.fromMillisecondsSinceEpoch(1792544523125, isUtc: true),
      );
      expect(result.lastActivityTimeSource, GatewayToolTimeSource.storedResult);
      final withObservedStart = GatewayToolActivity.fromStoredResult(
        name: 'terminal',
        timestamp: 1792544523,
        observedStart: DateTime.utc(2026, 10, 21),
      );
      expect(withObservedStart.startedAt, DateTime.utc(2026, 10, 21));
      final observedEnd = DateTime.utc(2026, 10, 21, 1, 2, 10);
      final fallback = GatewayToolActivity.fromStoredResult(
        name: 'terminal',
        timestamp: null,
        observedLastActivity: observedEnd,
      );
      expect(fallback.startedAt, isNull);
      expect(fallback.lastActivityAt, observedEnd);
      expect(fallback.lastActivityTimeSource, GatewayToolTimeSource.observed);
      for (final invalid in [
        null,
        '1792544523',
        -1,
        double.nan,
        double.infinity,
      ]) {
        final unknown = GatewayToolActivity.fromStoredResult(
          name: 'terminal',
          timestamp: invalid,
        );
        expect(unknown.startedAt, isNull);
        expect(unknown.lastActivityAt, isNull);
        expect(unknown.lastActivityTimeSource, isNull);
      }
    });
    test(
      'stored result phrases its summary from args or the context preview',
      () {
        final withArgs = GatewayToolActivity.fromStoredResult(
          name: 'read_file',
          timestamp: 1792544523,
          args: {'path': 'lib/core/models/gateway_activity.dart'},
        );
        expect(withArgs.summary, 'lib/core/models/gateway_activity.dart');
        expect(
          withArgs.displayTitle,
          'Read file: lib/core/models/gateway_activity.dart',
        );

        final withContext = GatewayToolActivity.fromStoredResult(
          name: 'terminal',
          timestamp: 1792544523,
          contextPreview: 'flutter analyze',
        );
        expect(withContext.summary, 'checking the code for issues');
        expect(
          withContext.displayTitle,
          'Terminal: checking the code for issues',
        );
      },
    );
  });

  group('GatewayTurnStatus', () {
    test('parses thinking and status updates', () {
      final thinking = GatewayTurnStatus.fromGatewayEvent('thinking.delta', {
        'text': '  Planning   the next step  ',
      });
      final compacting = GatewayTurnStatus.fromGatewayEvent('status.update', {
        'kind': 'compacting',
      });

      expect(thinking!.kind, 'thinking');
      expect(thinking.text, 'Planning the next step');
      expect(compacting!.text, 'Compacting conversation context…');
    });
  });

  group('GatewayActivityCard', () {
    testWidgets('shows active tool name, status, and safe detail', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GatewayActivityCard(
              activities: [
                GatewayToolActivity(
                  toolId: 'tool-1',
                  name: 'search_files',
                  phase: GatewayToolActivityPhase.progress,
                  detail: 'Scanning gateway event handlers',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tool activity'), findsOneWidget);
      expect(find.textContaining('Search files'), findsOneWidget);
      expect(find.text('Working'), findsOneWidget);
      expect(find.text('Scanning gateway event handlers'), findsOneWidget);
    });

    testWidgets('surfaces completed failures without raw result text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GatewayActivityCard(
              verbose: true,
              activities: [
                GatewayToolActivity(
                  toolId: 'tool-2',
                  name: 'terminal',
                  phase: GatewayToolActivityPhase.failed,
                  detail: 'Synthetic command failed',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1 failed • 1 total'), findsOneWidget);
      expect(find.textContaining('Terminal'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Synthetic command failed'), findsOneWidget);
    });
    testWidgets('expanded tool card exposes duration and full safe output', (
      tester,
    ) async {
      const detail =
          'Line one with a detailed result that must remain readable. '
          'Line two with additional context. Line three. Line four.';
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GatewayActivityCard(
              verbose: true,
              activities: [
                GatewayToolActivity(
                  toolId: 'tool-duration',
                  name: 'read_file',
                  phase: GatewayToolActivityPhase.completed,
                  durationSeconds: 1.25,
                  detail: detail,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completed in 1.3 s'), findsOneWidget);
      final detailWidget = tester.widget<Text>(find.text(detail));
      expect(detailWidget.maxLines, isNull);
    });

    testWidgets('tool row shows the semantic summary next to the tool name', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GatewayActivityCard(
              activities: [
                GatewayToolActivity(
                  toolId: 'tool-summary',
                  name: 'read_file',
                  phase: GatewayToolActivityPhase.running,
                  summary: 'lib/core/theme/hermes_theme.dart',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('Read file: lib/core/theme/hermes_theme.dart'),
        findsOneWidget,
      );
    });

    testWidgets('tool row without a summary keeps the bare tool name', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GatewayActivityCard(
              activities: [
                GatewayToolActivity(
                  toolId: 'tool-plain',
                  name: 'skills_list',
                  phase: GatewayToolActivityPhase.running,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Skills list'), findsOneWidget);
      expect(find.textContaining('Skills list:'), findsNothing);
    });
  });
}
