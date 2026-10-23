import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/hermes_theme.dart';

/// Where the app takes its color scheme from.
///
/// Stored as `system`, `hermesGold` or `seed:<argb hex>`; anything else reads
/// back as [ColorSource.system], so a corrupt or future value never breaks
/// launch.
@immutable
class ColorSource {
  const ColorSource._(this.kind, [this.seedColor]);

  /// The device wallpaper palette (Android 12+), seeded fallback elsewhere.
  static const ColorSource system = ColorSource._(ColorSourceKind.system);

  /// The upstream Hermes gold, as a tonal scheme.
  static const ColorSource hermesGold = ColorSource._(
    ColorSourceKind.hermesGold,
  );

  /// A user-picked seed color.
  const ColorSource.seed(Color color) : this._(ColorSourceKind.seed, color);

  final ColorSourceKind kind;
  final Color? seedColor;

  /// The seed to build the scheme from, or null to use the dynamic palette.
  Color? get seed => switch (kind) {
    ColorSourceKind.system => null,
    ColorSourceKind.hermesGold => HermesSeeds.hermesGold,
    ColorSourceKind.seed => seedColor,
  };

  String get storageValue => switch (kind) {
    ColorSourceKind.system => 'system',
    ColorSourceKind.hermesGold => 'hermesGold',
    ColorSourceKind.seed =>
      'seed:${seedColor!.toARGB32().toRadixString(16).padLeft(8, '0')}',
  };

  static ColorSource fromStorage(String? value) {
    if (value == 'hermesGold') return hermesGold;
    if (value != null && value.startsWith('seed:')) {
      final argb = int.tryParse(value.substring(5), radix: 16);
      if (argb != null) return ColorSource.seed(Color(argb | 0xFF000000));
    }
    return system;
  }

  @override
  bool operator ==(Object other) =>
      other is ColorSource &&
      other.kind == kind &&
      other.seedColor?.toARGB32() == seedColor?.toARGB32();

  @override
  int get hashCode => Object.hash(kind, seedColor?.toARGB32());

  @override
  String toString() => 'ColorSource($storageValue)';
}

enum ColorSourceKind { system, hermesGold, seed }

/// The persisted look of the app: theme mode, color source and pure black.
@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = ThemeMode.system,
    this.colorSource = ColorSource.system,
    this.pureBlack = false,
  });

  final ThemeMode themeMode;
  final ColorSource colorSource;
  final bool pureBlack;

  AppearanceSettings copyWith({
    ThemeMode? themeMode,
    ColorSource? colorSource,
    bool? pureBlack,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      colorSource: colorSource ?? this.colorSource,
      pureBlack: pureBlack ?? this.pureBlack,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppearanceSettings &&
      other.themeMode == themeMode &&
      other.colorSource == colorSource &&
      other.pureBlack == pureBlack;

  @override
  int get hashCode => Object.hash(themeMode, colorSource, pureBlack);
}

/// Current appearance, broadcast so the app root re-themes the moment
/// Settings (or a config restore) changes it — no ancestor-state rebuilds.
final ValueNotifier<AppearanceSettings> appearanceSelection = ValueNotifier(
  const AppearanceSettings(),
);

/// Reads and writes [AppearanceSettings] in [SharedPreferences], keeping
/// [appearanceSelection] in sync in both directions.
///
/// `theme_mode` keeps upstream's key and values (`system`/`dark`/`light`) so
/// an existing install or an upstream backup restores unchanged.
class AppearancePreferences {
  AppearancePreferences(this._preferences);

  static const themeModeKey = 'theme_mode';
  static const colorSourceKey = 'appearance_color_source';
  static const pureBlackKey = 'appearance_pure_black';

  /// Keys that belong in config backups.
  static const Set<String> backupKeys = {
    themeModeKey,
    colorSourceKey,
    pureBlackKey,
  };

  final SharedPreferences _preferences;

  AppearanceSettings read() {
    final settings = AppearanceSettings(
      themeMode: themeModeFromStorage(_preferences.getString(themeModeKey)),
      colorSource: ColorSource.fromStorage(
        _preferences.getString(colorSourceKey),
      ),
      pureBlack: _preferences.getBool(pureBlackKey) ?? false,
    );
    appearanceSelection.value = settings;
    return settings;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _preferences.setString(themeModeKey, themeModeToStorage(mode));
    appearanceSelection.value = appearanceSelection.value.copyWith(
      themeMode: mode,
    );
  }

  Future<void> setColorSource(ColorSource source) async {
    await _preferences.setString(colorSourceKey, source.storageValue);
    appearanceSelection.value = appearanceSelection.value.copyWith(
      colorSource: source,
    );
  }

  Future<void> setPureBlack(bool enabled) async {
    await _preferences.setBool(pureBlackKey, enabled);
    appearanceSelection.value = appearanceSelection.value.copyWith(
      pureBlack: enabled,
    );
  }

  static ThemeMode themeModeFromStorage(String? value) => switch (value) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => ThemeMode.system,
  };

  static String themeModeToStorage(ThemeMode mode) => switch (mode) {
    ThemeMode.dark => 'dark',
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
  };
}
