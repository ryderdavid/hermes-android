import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/settings_screen.dart';
import 'package:hermes_android/core/services/chat_density_preference.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('update controls remain available if dashboard settings fail', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(HermesApp(connManager: ConnectionManager(prefs)));
    await tester.pumpAndSettle();
    unawaited(
      Navigator.of(tester.element(find.byType(HomeScreen))).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(
            connection: SavedConnection(
              id: 'offline-dashboard',
              label: 'Offline dashboard',
              host: '127.0.0.1',
              port: 8642,
              dashboardPortOverride: 1,
              apiKey: 'test-only',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load settings'), findsOneWidget);
    await tester.ensureVisible(find.text('Check for updates on launch'));
    await tester.pumpAndSettle();
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Check for updates on launch'), findsOneWidget);
    await tester.tap(find.text('Check for updates on launch'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('app_update_check_on_launch_v1'), isFalse);
  });

  testWidgets('chat density remains usable if dashboard settings fail', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    chatDensitySelection.value = ChatDensity.comfortable;
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(HermesApp(connManager: ConnectionManager(prefs)));
    await tester.pumpAndSettle();
    unawaited(
      Navigator.of(tester.element(find.byType(HomeScreen))).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(
            connection: SavedConnection(
              id: 'offline-dashboard',
              label: 'Offline dashboard',
              host: '127.0.0.1',
              port: 8642,
              dashboardPortOverride: 1,
              apiKey: 'test-key',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.text('Chat density'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compact'));
    await tester.pumpAndSettle();
    expect(prefs.getString(ChatDensity.preferenceKey), 'compact');
    expect(chatDensitySelection.value, ChatDensity.compact);
  });

  testWidgets('About identifies the fork and checks the fork releases', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Hermes',
      packageName: 'com.ryderdavid.hermes_you',
      version: '2.1.30-you.1',
      buildNumber: '2173',
      buildSignature: '',
    );
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      return http.Response(
        '{"tag_name":"v2.1.30-you.2","name":"Hermes You 2.1.30-you.2",'
        '"body":"Composer polish.","draft":false,'
        '"html_url":"https://github.com/ryderdavid/hermes-android/releases/tag/v2.1.30-you.2",'
        '"published_at":"2026-10-23T09:30:00Z"}',
        200,
      );
    });

    await http.runWithClient(() async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(HermesApp(connManager: ConnectionManager(prefs)));
      await tester.pumpAndSettle();
      unawaited(
        Navigator.of(tester.element(find.byType(HomeScreen))).push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(
              connection: SavedConnection(
                id: 'offline-dashboard',
                label: 'Offline dashboard',
                host: '127.0.0.1',
                port: 8642,
                dashboardPortOverride: 1,
                apiKey: 'test-only',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Upstream project'));
      await tester.pumpAndSettle();
      expect(find.text('Material You fork'), findsOneWidget);
      expect(find.text('Fork on GitHub'), findsOneWidget);
      expect(find.text('github.com/ryderdavid/hermes-android'), findsOneWidget);
      expect(find.text('github.com/rusty4444/hermes-android'), findsOneWidget);

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
    }, () => client);

    // The launch-time check and the manual one both ask the fork, never
    // upstream, whose APKs could not upgrade this install.
    final githubPaths = requested
        .where((uri) => uri.host == 'api.github.com')
        .map((uri) => uri.path)
        .toSet();
    expect(githubPaths, {'/repos/ryderdavid/hermes-android/releases/latest'});
    expect(find.text('Update available'), findsOneWidget);
    expect(find.textContaining('2.1.30-you.2'), findsWidgets);
  });
}
