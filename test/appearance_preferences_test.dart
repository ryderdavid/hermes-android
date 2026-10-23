import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/appearance_preferences.dart';
import 'package:hermes_android/core/services/config_backup_service.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryCredentialStore implements CredentialStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  String? readCached(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<ConfigBackupService> _backupService(SharedPreferences prefs) async {
  final manager = await ConnectionManager.create(
    prefs,
    credentialStore: _MemoryCredentialStore(),
  );
  return ConfigBackupService(connectionManager: manager, preferences: prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => appearanceSelection.value = const AppearanceSettings());

  group('ColorSource storage', () {
    test('round-trips every kind', () {
      for (final source in [
        ColorSource.system,
        ColorSource.hermesGold,
        const ColorSource.seed(Color(0xFF34A853)),
      ]) {
        expect(ColorSource.fromStorage(source.storageValue), source);
      }
    });

    test('unknown or corrupt values fall back to system', () {
      expect(ColorSource.fromStorage(null), ColorSource.system);
      expect(ColorSource.fromStorage('rainbow'), ColorSource.system);
      expect(ColorSource.fromStorage('seed:zz'), ColorSource.system);
    });

    test('maps each kind to the seed the scheme is built from', () {
      expect(ColorSource.system.seed, isNull);
      expect(ColorSource.hermesGold.seed, HermesSeeds.hermesGold);
      expect(
        const ColorSource.seed(Color(0xFF7E57C2)).seed,
        const Color(0xFF7E57C2),
      );
    });
  });

  group('AppearancePreferences', () {
    test('defaults to system mode, system color, pure black off', () async {
      final settings = AppearancePreferences(await _prefs({})).read();

      expect(settings, const AppearanceSettings());
      expect(appearanceSelection.value, settings);
    });

    test('reads the upstream theme_mode key unchanged', () async {
      final settings = AppearancePreferences(
        await _prefs({'theme_mode': 'dark'}),
      ).read();

      expect(settings.themeMode, ThemeMode.dark);
    });

    test('persists every setting and broadcasts each change', () async {
      final prefs = await _prefs({});
      final store = AppearancePreferences(prefs);
      final seen = <AppearanceSettings>[];
      void listener() => seen.add(appearanceSelection.value);
      appearanceSelection.addListener(listener);
      addTearDown(() => appearanceSelection.removeListener(listener));

      await store.setThemeMode(ThemeMode.light);
      await store.setColorSource(ColorSource.hermesGold);
      await store.setPureBlack(true);

      expect(seen, hasLength(3));
      expect(prefs.getString('theme_mode'), 'light');
      expect(
        prefs.getString(AppearancePreferences.colorSourceKey),
        'hermesGold',
      );
      expect(prefs.getBool(AppearancePreferences.pureBlackKey), isTrue);

      appearanceSelection.value = const AppearanceSettings();
      expect(
        AppearancePreferences(prefs).read(),
        const AppearanceSettings(
          themeMode: ThemeMode.light,
          colorSource: ColorSource.hermesGold,
          pureBlack: true,
        ),
      );
    });
  });

  group('config backup', () {
    test('every appearance key is backed up', () {
      for (final key in AppearancePreferences.backupKeys) {
        expect(ConfigBackupService.isBackedUpKey(key), isTrue, reason: key);
      }
    });

    test('round-trips appearance and refreshes the live selection', () async {
      final sourcePrefs = await _prefs({});
      final sourceStore = AppearancePreferences(sourcePrefs);
      await sourceStore.setThemeMode(ThemeMode.dark);
      await sourceStore.setColorSource(
        const ColorSource.seed(Color(0xFFE91E63)),
      );
      await sourceStore.setPureBlack(true);
      final backup = await (await _backupService(
        sourcePrefs,
      )).export(appVersion: 'test');

      final targetPrefs = await _prefs({});
      appearanceSelection.value = const AppearanceSettings();
      await (await _backupService(
        targetPrefs,
      )).import(backup, mode: ConfigImportMode.merge);

      const expected = AppearanceSettings(
        themeMode: ThemeMode.dark,
        colorSource: ColorSource.seed(Color(0xFFE91E63)),
        pureBlack: true,
      );
      expect(appearanceSelection.value, expected);
      expect(AppearancePreferences(targetPrefs).read(), expected);
    });
  });
}
