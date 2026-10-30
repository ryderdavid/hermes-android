import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/appearance_screen.dart';
import 'package:hermes_android/core/screens/settings_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/main.dart';
import 'package:http/http.dart' as http;

import '../support/fake_dashboard.dart';
import 'app_golden_harness.dart';
import 'golden_harness.dart';

final _connection = SavedConnection(
  id: 'golden',
  label: 'Miniserver',
  host: 'miniserver.ts.net',
  port: 8642,
  apiKey: 'fixture-key',
);

void main() {
  for (final variant in goldenMatrix) {
    testWidgets('settings ${variant.name}', (tester) async {
      await http.runWithClient(() async {
        await pumpGoldenApp(
          tester,
          variant: variant,
          size: const Size(412, 4400),
        );
        unawaited(
          Navigator.of(tester.element(find.byType(HomeScreen))).push(
            MaterialPageRoute<void>(
              builder: (_) => SettingsScreen(connection: _connection),
            ),
          ),
        );
        // The TTS voice list never answers in tests, so its spinner never
        // settles; advance far enough for everything else to load.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }, fakeDashboardClient);
      expect(find.text('Profile default model'), findsWidgets);
      await matchGolden(tester, 'screens/settings_${variant.name}.png');
    });
  }

  for (final variant in goldenMatrix) {
    testWidgets('appearance ${variant.name}', (tester) async {
      await pumpGoldenApp(
        tester,
        variant: variant,
        size: const Size(412, 1400),
      );
      unawaited(
        Navigator.of(tester.element(find.byType(HomeScreen))).push(
          MaterialPageRoute<void>(builder: (_) => const AppearanceScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await matchGolden(tester, 'screens/appearance_${variant.name}.png');
    });
  }
}
