import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/expressive/expressive.dart';
import 'package:hermes_android/core/screens/appearance_screen.dart';
import 'package:hermes_android/core/screens/settings_screen.dart';
import 'package:hermes_android/core/services/appearance_preferences.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/core/widgets/appearance_color_picker.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:hermes_android/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _offline = SavedConnection(
  id: 'offline-dashboard',
  label: 'Offline dashboard',
  host: '127.0.0.1',
  port: 8642,
  dashboardPortOverride: 1,
  apiKey: 'test-only',
);

Future<SharedPreferences> _openSettings(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(HermesApp(connManager: ConnectionManager(prefs)));
  await tester.pumpAndSettle();
  unawaited(
    Navigator.of(tester.element(find.byType(HomeScreen))).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(connection: _offline),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Colors live on the Appearance page, one tap in from Settings.
  await tester.tap(find.byKey(const Key('settings-appearance')));
  await tester.pumpAndSettle();
  return prefs;
}

Color _primary(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(AppearanceScreen))).colorScheme.primary;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    appearanceSelection.value = const AppearanceSettings();
  });

  testWidgets('choosing Hermes gold re-themes at once and persists', (
    tester,
  ) async {
    final prefs = await _openSettings(tester);
    final gold = find.byKey(const ValueKey('color-swatch-hermesGold'));
    await tester.ensureVisible(gold);
    await tester.pumpAndSettle();

    await tester.tap(gold);
    await tester.pumpAndSettle();

    expect(appearanceSelection.value.colorSource, ColorSource.hermesGold);
    expect(prefs.getString(AppearancePreferences.colorSourceKey), 'hermesGold');
    expect(
      _primary(tester),
      hermesColorScheme(Brightness.light, seed: HermesSeeds.hermesGold).primary,
    );

    // A preset seed works the same way and replaces the choice.
    final green = find.byKey(
      ValueKey(
        'color-swatch-${ColorSource.seed(HermesSeeds.presets[1]).storageValue}',
      ),
    );
    await tester.tap(green);
    await tester.pumpAndSettle();
    expect(
      _primary(tester),
      hermesColorScheme(Brightness.light, seed: HermesSeeds.presets[1]).primary,
    );
    expect(
      AppearancePreferences(prefs).read().colorSource,
      ColorSource.seed(HermesSeeds.presets[1]),
    );
  });

  testWidgets('pure black switch persists and applies to the dark theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final prefs = await _openSettings(tester);
    final toggle = find.byKey(const Key('appearance-pure-black'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(prefs.getBool(AppearancePreferences.pureBlackKey), isTrue);
    expect(
      Theme.of(
        tester.element(find.byType(AppearanceScreen)),
      ).colorScheme.surface,
      const Color(0xFF000000),
    );
  });

  testWidgets('Wallpaper is disabled without a dynamic palette', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: hermesTheme(Brightness.light),
        home: Scaffold(
          body: AppearanceColorPicker(
            preferences: AppearancePreferences(prefs),
            dynamicAvailable: false,
          ),
        ),
      ),
    );
    final handle = tester.ensureSemantics();

    final wallpaper = find.byKey(const ValueKey('color-swatch-system'));
    expect(
      find.text('Wallpaper colors need Android 12 or later'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Wallpaper')),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
    await tester.tap(wallpaper, warnIfMissed: false);
    await tester.pump();
    expect(prefs.getString(AppearancePreferences.colorSourceKey), isNull);
    handle.dispose();
  });

  testWidgets('Wallpaper is selectable with a dynamic palette', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppearancePreferences.colorSourceKey: 'hermesGold',
    });
    final prefs = await SharedPreferences.getInstance();
    AppearancePreferences(prefs).read();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: hermesTheme(Brightness.light),
        home: Scaffold(
          body: AppearanceColorPicker(
            preferences: AppearancePreferences(prefs),
            dynamicAvailable: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('color-swatch-system')));
    await tester.pump();

    expect(prefs.getString(AppearancePreferences.colorSourceKey), 'system');
    expect(find.text('Matches your wallpaper'), findsOneWidget);
  });

  testWidgets('a stored seed equal to a swatch highlights that swatch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppearancePreferences.colorSourceKey: ColorSource.seed(
        HermesSeeds.hermesGold,
      ).storageValue,
    });
    final prefs = await SharedPreferences.getInstance();
    AppearancePreferences(prefs).read();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: hermesTheme(Brightness.light),
        home: Scaffold(
          body: AppearanceColorPicker(
            preferences: AppearancePreferences(prefs),
            dynamicAvailable: false,
          ),
        ),
      ),
    );

    expect(find.text('Hermes gold'), findsOneWidget);
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Hermes gold')),
      isSemantics(isButton: true, hasSelectedState: true, isSelected: true),
    );
    handle.dispose();
  });
  testWidgets('the theme group switches to dark at once and persists', (
    tester,
  ) async {
    final prefs = await _openSettings(tester);
    expect(find.byType(ConnectedButtonView), findsNWidgets(3));

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(appearanceSelection.value.themeMode, ThemeMode.dark);
    expect(prefs.getString('theme_mode'), 'dark');
    expect(
      Theme.of(tester.element(find.byType(AppearanceScreen))).brightness,
      Brightness.dark,
    );
  });
}
