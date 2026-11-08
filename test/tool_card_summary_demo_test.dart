import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/gateway_activity.dart';
import 'package:hermes_android/core/widgets/gateway_activity_card.dart';
import 'package:hermes_android/l10n/app_localizations.dart';

/// Demo run: three running tool calls in one activity card, rendered exactly
/// as the chat shows them — run with
/// `flutter test test/tool_card_summary_demo_test.dart`.
void main() {
  testWidgets('demo: three tool rows with semantic summaries', (tester) async {
    // Real gateway tool.start payloads (name + args), as the WS event ships.
    final activities = [
      GatewayToolActivity.fromGatewayEvent('tool.start', {
        'tool_id': 'call-1',
        'name': 'patch',
        'args': {
          'path':
              '/Users/ryder/Code/hermes-android/lib/core/widgets/gateway_activity_card.dart',
        },
      })!,
      GatewayToolActivity.fromGatewayEvent('tool.start', {
        'tool_id': 'call-2',
        'name': 'terminal',
        'args': {'command': 'flutter test test/gateway_activity_test.dart'},
      })!,
      GatewayToolActivity.fromGatewayEvent('tool.start', {
        'tool_id': 'call-3',
        'name': 'search_files',
        'args': {'pattern': 'GatewayActivityCard'},
      })!,
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390, // phone-width surface
              child: GatewayActivityCard(activities: activities),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    // ignore: avoid_print — this test exists to show the rendered rows.
    print(
      '=== RENDERED CARD (390dp wide, 3 running tools, auto-expanded) ===\n'
      '${rendered.map((line) => '  | $line').join('\n')}\n'
      '==================================================================',
    );

    expect(
      find.textContaining(
        'Patch: /Users/ryder/Code/hermes-android/lib/core/widgets/gateway_activity_card.dart',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Terminal: running the test suite'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Search files: GatewayActivityCard'),
      findsOneWidget,
    );
  });
}
