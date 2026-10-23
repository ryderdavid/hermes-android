import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/appearance_preferences.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

/// Preferences that make [HermesApp] render [variant]: theme mode, the seed
/// as the color source (test hosts have no wallpaper palette) and pure black.
Map<String, Object> appearancePrefsFor(GoldenVariant variant) => {
  AppearancePreferences.themeModeKey: variant.brightness == Brightness.dark
      ? 'dark'
      : 'light',
  AppearancePreferences.colorSourceKey: ColorSource.seed(
    variant.seed,
  ).storageValue,
  AppearancePreferences.pureBlackKey: variant.pureBlack,
};

/// Pumps the real app root for [variant] with [prefs] merged in.
Future<ConnectionManager> pumpGoldenApp(
  WidgetTester tester, {
  required GoldenVariant variant,
  Map<String, Object> prefs = const {},
  Size size = goldenPhoneSize,
}) async {
  debugDisableShadows = false;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    ...appearancePrefsFor(variant),
    ...prefs,
  });
  final manager = ConnectionManager(await SharedPreferences.getInstance());
  await tester.pumpWidget(HermesApp(connManager: manager));
  await tester.pumpAndSettle();
  return manager;
}
