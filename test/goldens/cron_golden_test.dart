import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/cron_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';

import 'golden_harness.dart';

/// A connection whose dashboard never answers, so Cron lands on its error
/// state without a network.
final _offline = SavedConnection(
  id: 'offline-dashboard',
  label: 'Offline dashboard',
  host: '127.0.0.1',
  port: 8642,
  dashboardPortOverride: 1,
  apiKey: 'test-only',
);

void main() {
  for (final variant in goldenMatrix) {
    testWidgets('cron error ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        CronScreen(connection: _offline),
        variant: variant,
      );
      await matchGolden(tester, 'screens/cron_error_${variant.name}.png');
    });

    testWidgets('cron editor ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        CronScreen(connection: _offline),
        variant: variant,
      );
      await tester.tap(find.byTooltip('Add new cron job'));
      await tester.pumpAndSettle();
      await matchGolden(tester, 'fields/cron_editor_${variant.name}.png');
    });
  }
}
