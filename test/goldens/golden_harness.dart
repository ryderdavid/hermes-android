import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/l10n/app_localizations.dart';

/// A fixed-seed stand-in for the wallpaper palette, so dynamic-color goldens
/// are deterministic.
const Color goldenBlueSeed = Color(0xFF4285F4);

/// One cell of the golden matrix.
class GoldenVariant {
  const GoldenVariant(
    this.name,
    this.brightness,
    this.seed, {
    this.pureBlack = false,
  });

  final String name;
  final Brightness brightness;
  final Color seed;
  final bool pureBlack;

  ThemeData get theme => hermesTheme(
    brightness,
    colorScheme: hermesColorScheme(
      brightness,
      seed: seed,
      pureBlack: pureBlack,
    ),
  );
}

/// {light, dark, dark + pure black} × {blue seed, Hermes gold}.
const List<GoldenVariant> goldenMatrix = [
  GoldenVariant('light_blue', Brightness.light, goldenBlueSeed),
  GoldenVariant('dark_blue', Brightness.dark, goldenBlueSeed),
  GoldenVariant('black_blue', Brightness.dark, goldenBlueSeed, pureBlack: true),
  GoldenVariant('light_gold', Brightness.light, HermesSeeds.hermesGold),
  GoldenVariant('dark_gold', Brightness.dark, HermesSeeds.hermesGold),
  GoldenVariant(
    'black_gold',
    Brightness.dark,
    HermesSeeds.hermesGold,
    pureBlack: true,
  ),
];

/// Phone-sized surface used by every golden unless a test overrides it.
const Size goldenPhoneSize = Size(412, 892);

Future<void> pumpGolden(
  WidgetTester tester,
  Widget home, {
  required GoldenVariant variant,
  Size size = goldenPhoneSize,
  double textScale = 1.0,
  bool settle = true,
}) async {
  // Real elevation shadows instead of the test binding's solid outlines.
  // [matchGolden] restores the flag, which the binding checks before
  // tear-down runs.
  debugDisableShadows = false;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: variant.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Spinners never settle; advance to a fixed frame instead.
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Compares the whole app against [path] and restores the shadow debug flag
/// that [pumpGolden] turned off.
Future<void> matchGolden(WidgetTester tester, String path) async {
  try {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(path));
  } finally {
    debugDisableShadows = true;
  }
}
