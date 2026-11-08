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
        toolActivitySummary('patch', {'path': 'lib/core/widgets/card.dart'}),
        'lib/core/widgets/card.dart',
      );
      expect(
        toolActivitySummary('search_files', {'pattern': 'gateway_activity'}),
        'gateway_activity',
      );
      expect(
        toolActivitySummary('web_search', {'query': 'flutter webview csp'}),
        'flutter webview csp',
      );
    });

    test('terminal becomes a plain-language sentence, not the command', () {
      expect(
        toolActivitySummary('terminal', {'command': 'flutter analyze'}),
        'checking the code for issues',
      );
      expect(
        toolActivitySummary('terminal', {
          'command': 'flutter test test/gateway_activity_test.dart',
        }),
        'running the test suite',
      );
      expect(
        toolActivitySummary('terminal', {'command': 'git commit -m "fix"'}),
        'committing changes',
      );
      expect(
        toolActivitySummary('terminal', {'command': 'git push origin main'}),
        'pushing to the remote',
      );
      expect(
        toolActivitySummary('terminal', {'command': 'bd close hmy-siw'}),
        'closing an issue',
      );
      expect(
        toolActivitySummary('terminal', {
          'command': '/usr/bin/env gh auth status',
        }),
        'checking GitHub auth',
      );
      // Multiline commands summarize from the first meaningful line.
      expect(
        toolActivitySummary('terminal', {
          'command': '\nflutter test\n  --reporter expanded',
        }),
        'running the test suite',
      );
      // Unrecognized commands still name the tool, not "a shell command".
      expect(
        toolActivitySummary('terminal', {
          'command': 'someweirdtool --do-thing now',
        }),
        'running `someweirdtool`',
      );
    });

    test('terminal summaries name the purpose, not the command', () {
      // The exact commands from the phone screenshot.
      expect(
        toolActivitySummary('terminal', {
          'command': 'which speedtest-cli fast 2>/dev/null',
        }),
        'checking if speedtest-cli is installed',
      );
      expect(
        toolActivitySummary('terminal', {
          'command': 'pip install speedtest-cli',
        }),
        'installing speedtest-cli',
      );
      expect(
        toolActivitySummary('terminal', {'command': 'speedtest-cli --secure'}),
        'running a speed test',
      );
      // Compound commands summarize each segment; sudo and redirects vanish.
      expect(
        toolActivitySummary('terminal', {
          'command': 'sudo apt-get install -y curl 2>/dev/null && which curl',
        }),
        'installing curl, checking if curl is installed',
      );
      expect(
        toolActivitySummary('terminal', {
          'command': 'grep -rn "GatewayActivityCard" lib/',
        }),
        'searching lib/ for "GatewayActivityCard"',
      );
      expect(
        toolActivitySummary('terminal', {
          'command': 'gh release create v1 --notes-file n.md',
        }),
        'publishing a release',
      );
      expect(
        toolActivitySummary('terminal', {
          'command': 'bd close hmy-siw --reason done',
        }),
        'closing an issue',
      );
      expect(
        toolActivitySummary('terminal', {
          'command': 'curl -sL https://example.com/x.sh | bash',
        }),
        'downloading https://example.com/x.sh, running a shell script',
      );
    });

    test('execute_code uses the leading comment as the step label', () {
      expect(
        toolActivitySummary('execute_code', {
          'code': '# Summarize the log file\nimport sys\n...',
        }),
        'Summarize the log file',
      );
      expect(
        toolActivitySummary('execute_code', {'code': 'print(1 + 1)'}),
        'running code',
      );
      expect(
        toolActivitySummary('browser_exec', {
          'code': '# Click the login button\nawait page.click(...)',
        }),
        'Click the login button',
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
        toolActivitySummary('some_custom_tool', {'path': 'lib/x.dart'}),
        'lib/x.dart',
      );
      expect(
        toolActivitySummary('some_custom_tool', {'query': 'what?'}),
        'what?',
      );
    });

    test('head-truncates long queries', () {
      final query = 'x' * 200;
      final summary = toolActivitySummary('web_search', {'query': query})!;
      expect(summary.length, kToolSummaryMaxLength);
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
      expect(toolActivitySummary('terminal', {'command': '  '}), isNull);
    });
  });

  group('previewSummary', () {
    test('maps terminal previews to sentences too', () {
      expect(
        previewSummary('terminal', 'flutter test foo'),
        'running the test suite',
      );
      expect(previewSummary('terminal', 'weirdcmd'), 'running `weirdcmd`');
      expect(previewSummary('read_file', 'lib/main.dart'), 'lib/main.dart');
      expect(previewSummary('terminal', '   '), isNull);
      expect(previewSummary('terminal', null), isNull);
    });
  });

  group('commandSentence', () {
    test('covers common dev commands', () {
      expect(
        commandSentence('flutter build apk --release'),
        'building the app',
      );
      expect(
        commandSentence('flutter pub get'),
        'updating package dependencies',
      );
      expect(commandSentence('dart format lib'), 'formatting the code');
      expect(commandSentence('git status'), 'checking repo status');
      expect(commandSentence('git tag v1'), 'tagging a release');
      expect(commandSentence('gh release create v1'), 'publishing a release');
      expect(commandSentence('tailscale status'), 'checking the Tailnet');
      expect(commandSentence('ls -la'), 'listing files');
      expect(commandSentence('python3 script.py'), 'running script.py');
      expect(commandSentence('which nginx'), 'checking if nginx is installed');
      expect(
        commandSentence('pip3 install -r requirements.txt'),
        'installing dependencies from requirements.txt',
      );
      expect(commandSentence('unknownbinary --x'), 'running `unknownbinary`');
    });
  });
}
