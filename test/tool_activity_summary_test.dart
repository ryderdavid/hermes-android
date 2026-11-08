import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/utils/tool_activity_summary.dart';

void main() {
  group('toolActivitySummary', () {
    test('uses the curated primary arg for known tools', () {
      expect(
        toolActivitySummary('read_file', {'path': 'lib/main.dart'}),
        'lib/main.dart',
      );
      expect(
        toolActivitySummary('search_files', {'pattern': 'gateway_activity'}),
        'gateway_activity',
      );
      expect(
        toolActivitySummary('web_search', {'query': 'flutter webview csp'}),
        'flutter webview csp',
      );
      expect(
        toolActivitySummary('terminal', {'command': 'flutter analyze'}),
        'flutter analyze',
      );
    });

    test('falls back to generic arg keys for unknown tools', () {
      expect(
        toolActivitySummary('mcp__ynab__create_transaction', {
          'amount': 12,
          'memo': 'coffee',
        }),
        isNull, // neither key is summarizable
      );
      expect(
        toolActivitySummary('some_custom_tool', {'command': 'make build'}),
        'make build',
      );
      expect(
        toolActivitySummary('some_custom_tool', {'query': 'what?'}),
        'what?',
      );
    });

    test('collapses multiline values to one line', () {
      expect(
        toolActivitySummary('terminal', {
          'command': 'flutter test\n  --reporter expanded',
        }),
        'flutter test --reporter expanded',
      );
    });

    test('head-truncates long commands and queries', () {
      final command = 'flutter test ${'x' * 200}';
      final summary = toolActivitySummary('terminal', {'command': command})!;
      expect(summary.length, kToolSummaryMaxLength);
      expect(summary.startsWith('flutter test '), isTrue);
      expect(summary.endsWith('…'), isTrue);
    });

    test('tail-truncates long paths so the file name survives', () {
      final path =
          '/Users/ryder/Code/${'very/' * 40}hermes-android/lib/main.dart';
      final summary = toolActivitySummary('read_file', {'path': path})!;
      expect(summary.length, kToolSummaryMaxLength);
      expect(summary.startsWith('…'), isTrue);
      expect(summary.endsWith('hermes-android/lib/main.dart'), isTrue);
    });

    test('uses the first entry of list args', () {
      expect(
        toolActivitySummary('web_extract', {
          'urls': ['https://example.com/a', 'https://example.com/b'],
        }),
        'https://example.com/a',
      );
    });

    test('delegate_task summarizes steer/stop/list and spawn goals', () {
      expect(
        toolActivitySummary('delegate_task', {
          'action': 'steer',
          'subagent_id': 'worker-7',
        }),
        'steer worker-7',
      );
      expect(
        toolActivitySummary('delegate_task', {
          'action': 'spawn',
          'tasks': [
            {'goal': 'Research the gateway tool progress contract'},
          ],
        }),
        'Research the gateway tool progress contract',
      );
      expect(
        toolActivitySummary('delegate_task', {
          'action': 'spawn',
          'goal': 'One-off goal',
        }),
        'One-off goal',
      );
    });

    test('clarify summarizes the first question', () {
      expect(
        toolActivitySummary('clarify', {
          'questions': [
            {'question': 'Which provider should I use?'},
          ],
        }),
        'Which provider should I use?',
      );
    });

    test('never surfaces sensitive arg values', () {
      expect(
        toolActivitySummary('custom_auth_tool', {
          'api_key': 'sk-live-123',
          'path': 'lib/secrets.dart',
        }),
        'lib/secrets.dart', // sensitive key skipped, next key used
      );
      expect(
        toolActivitySummary('custom_auth_tool', {'token': 'sk-live-123'}),
        isNull,
      );
      expect(
        toolActivitySummary('memory', {'target': 'memory', 'operations': []}),
        'memory',
      );
    });

    test('returns null when there is nothing to summarize', () {
      expect(toolActivitySummary('skills_list', null), isNull);
      expect(toolActivitySummary('skills_list', {}), isNull);
      expect(toolActivitySummary('skills_list', {'category': null}), isNull);
      expect(toolActivitySummary('read_file', {'path': '   '}), isNull);
    });
  });
}
