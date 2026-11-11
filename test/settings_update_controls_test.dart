import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/appearance_screen.dart';
import 'package:hermes_android/core/screens/settings_screen.dart';
import 'package:hermes_android/core/services/chat_density_preference.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/widgets/settings_group.dart';
import 'package:hermes_android/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_dashboard.dart';

/// Settings is a lazy list grouped into sections, so a row far down may not
/// be built yet: scroll until it is, then bring it fully on screen.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

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
    await _scrollTo(tester, find.text('Check for updates on launch'));
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
    await tester.tap(find.byKey(const Key('settings-appearance')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Chat density'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(AppearanceScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat density'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compact'));
    await tester.pumpAndSettle();
    expect(prefs.getString(ChatDensity.preferenceKey), 'compact');
    expect(chatDensitySelection.value, ChatDensity.compact);
  });

  testWidgets('message metadata is a debugging toggle in the About group', (
    tester,
  ) async {
    // Tall enough to lay out every group of the lazy settings list.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 4400);
    addTearDown(tester.view.reset);
    // A user who had Verbose Mode on before the rename.
    SharedPreferences.setMockInitialValues({'verbose_mode': true});
    final prefs = await SharedPreferences.getInstance();
    await http.runWithClient(() async {
      await tester.pumpWidget(HermesApp(connManager: ConnectionManager(prefs)));
      await tester.pumpAndSettle();
      unawaited(
        Navigator.of(tester.element(find.byType(HomeScreen))).push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(
              connection: SavedConnection(
                id: 'golden',
                label: 'Miniserver',
                host: 'miniserver.ts.net',
                port: 8642,
                apiKey: 'fixture-key',
              ),
            ),
          ),
        ),
      );
      // The TTS voice list never answers in tests, so its spinner never
      // settles; advance far enough for the dashboard settings to load.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }, fakeDashboardClient);
    // The dashboard answered, so this is the full settings list.
    expect(find.text('Failed to load settings'), findsNothing);

    final toggle = find.byKey(const Key('settings-message-metadata'));
    final appearance = find.byKey(const Key('settings-appearance'));
    expect(appearance, findsOneWidget);
    expect(toggle, findsOneWidget);

    // It is no longer next to Appearance at the top of Settings.
    expect(
      find.descendant(
        of: find.ancestor(of: appearance, matching: find.byType(SettingsGroup)),
        matching: toggle,
      ),
      findsNothing,
    );

    expect(find.text('Show message metadata'), findsOneWidget);
    expect(
      find.text("For debugging: shows each message's stored fields"),
      findsOneWidget,
    );
    expect(find.text('Verbose Mode'), findsNothing);
    // It sits in the About group, below the About card and nothing else.
    final about = find.ancestor(
      of: find.text('Material You fork'),
      matching: find.byType(SettingsGroup),
    );
    expect(tester.widget<SettingsGroup>(about).title, 'About');
    expect(find.descendant(of: about, matching: toggle), findsOneWidget);
    expect(
      tester.getTopLeft(toggle).dy,
      greaterThan(tester.getTopLeft(find.text('Material You fork')).dy),
    );

    // The saved value keeps its effect, under the same key.
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pump(const Duration(milliseconds: 200));
    expect(prefs.getBool('verbose_mode'), isFalse);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });

  testWidgets('the message metadata toggle stays available if dashboard '
      'settings fail', (tester) async {
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

    await _scrollTo(tester, find.text('Show message metadata'));
    await tester.tap(find.text('Show message metadata'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('verbose_mode'), isTrue);
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

      await _scrollTo(tester, find.text('Upstream project'));
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
