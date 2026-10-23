import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/workspace_screen.dart';
import 'package:hermes_android/core/services/appearance_preferences.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/main.dart';
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

Future<void> _settle(WidgetTester tester) async {
  // The workspace keeps polling, so advance time rather than settle.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

int _workspaces() =>
    find.byType(WorkspaceScreen, skipOffstage: false).evaluate().length;

void main() {
  setUp(() => appearanceSelection.value = const AppearanceSettings());

  testWidgets('launch reopens the last workspace once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final manager = await ConnectionManager.create(
      prefs,
      credentialStore: _MemoryCredentialStore(),
    );
    await manager.saveConnection('Home', '127.0.0.1', 18642, 'test-key');
    await prefs.setString(
      'last_connection_id',
      manager.getConnections().single.id,
    );

    await tester.pumpWidget(HermesApp(connManager: manager));
    await _settle(tester);
    expect(_workspaces(), 1);

    await AppearancePreferences(prefs).setColorSource(ColorSource.hermesGold);
    await _settle(tester);
    expect(_workspaces(), 1);
  });

  testWidgets(
    'changing appearance after adding a connection does not open another '
    'workspace',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final manager = await ConnectionManager.create(
        prefs,
        credentialStore: _MemoryCredentialStore(),
      );
      await tester.pumpWidget(HermesApp(connManager: manager));
      await tester.pumpAndSettle();

      // First run: add a connection, then open it by hand.
      await manager.saveConnection('Home', '127.0.0.1', 18642, 'test-key');
      tester
          .state<HomeScreenState>(find.byType(HomeScreen))
          .refreshConnections();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').first);
      await _settle(tester);
      expect(_workspaces(), 1);

      // Re-theming re-runs HomeScreen.didChangeDependencies.
      await AppearancePreferences(prefs).setColorSource(ColorSource.hermesGold);
      await _settle(tester);
      await AppearancePreferences(prefs).setThemeMode(ThemeMode.dark);
      await _settle(tester);
      expect(_workspaces(), 1);
    },
  );
}
