import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';

String _read(String path) => File(path).readAsStringSync();

const _res = 'android/app/src/main/res';

void main() {
  test('both adaptive icons carry the monochrome layer', () {
    for (final icon in ['ic_launcher', 'ic_launcher_round']) {
      final xml = _read('$_res/mipmap-anydpi-v26/$icon.xml');
      expect(
        xml,
        contains(
          '<monochrome android:drawable="@drawable/ic_launcher_monochrome" />',
        ),
        reason: icon,
      );
      expect(xml, contains('@drawable/ic_launcher_foreground'), reason: icon);
    }
    expect(
      File('$_res/drawable/ic_launcher_monochrome.xml').existsSync(),
      isTrue,
    );
  });

  test('launch uses the AndroidX splash in light and dark', () {
    for (final dir in [
      'values',
      'values-night',
      'values-v27',
      'values-night-v27',
    ]) {
      final styles = _read('$_res/$dir/styles.xml');
      expect(styles, contains('parent="Theme.SplashScreen"'), reason: dir);
      expect(
        styles,
        contains(
          '<item name="postSplashScreenTheme">@style/NormalTheme</item>',
        ),
        reason: dir,
      );
      expect(styles, contains('@drawable/splash_glyph'), reason: dir);
      expect(
        styles,
        contains(
          '<item name="android:navigationBarColor">@android:color/transparent</item>',
        ),
        reason: dir,
      );
    }
    expect(
      _read('$_res/values-night/colors.xml'),
      contains('splash_background'),
    );
    expect(
      _read('$_res/values-v31/colors.xml'),
      contains('@android:color/system_neutral1_10'),
    );
    final activity = _read(
      'android/app/src/main/kotlin/com/hermesagent/hermes_android/MainActivity.kt',
    );
    expect(
      activity.indexOf('installSplashScreen()'),
      lessThan(activity.indexOf('super.onCreate(savedInstanceState)')),
    );
    expect(
      _read('android/app/build.gradle.kts'),
      contains('androidx.core:core-splashscreen'),
    );
  });

  test('the app opts in to predictive back', () {
    expect(
      _read('android/app/src/main/AndroidManifest.xml'),
      contains('android:enableOnBackInvokedCallback="true"'),
    );
    final theme = hermesTheme(Brightness.light);
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
  });

  test('system bars are transparent with icons that follow the theme', () {
    for (final brightness in Brightness.values) {
      final style = hermesSystemUiStyle(hermesColorScheme(brightness));
      final icons = brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark;
      expect(style.statusBarColor, const Color(0x00000000));
      expect(style.systemNavigationBarColor, const Color(0x00000000));
      expect(style.statusBarIconBrightness, icons);
      expect(style.systemNavigationBarIconBrightness, icons);
      expect(
        hermesTheme(brightness).appBarTheme.systemOverlayStyle,
        isA<SystemUiOverlayStyle>(),
      );
    }
    expect(_read('lib/main.dart'), contains('SystemUiMode.edgeToEdge'));
    // Below Android 10 the app is not drawn behind the bar: paint it.
    final scheme = hermesColorScheme(Brightness.dark);
    expect(
      hermesSystemUiStyle(scheme, edgeToEdge: false).systemNavigationBarColor,
      scheme.surface,
    );
  });
}
