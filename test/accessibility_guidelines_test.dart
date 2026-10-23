import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/screens/cron_screen.dart';
import 'package:hermes_android/core/screens/workspace_screen.dart';
import 'package:hermes_android/core/screens/settings_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:hermes_android/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/composer_harness.dart';
import 'support/fake_voice_composer_adapter.dart';
import 'support/fixture_gateway.dart';

/// Android accessibility guidelines checked on real screens, in light and
/// dark, for the fallback blue scheme and Hermes gold.
final _schemes = <String, ThemeData>{
  for (final brightness in Brightness.values)
    for (final (name, seed) in [
      ('blue', HermesSeeds.fallback),
      ('gold', HermesSeeds.hermesGold),
    ])
      '${brightness.name} $name': hermesTheme(
        brightness,
        colorScheme: hermesColorScheme(brightness, seed: seed),
      ),
};

final _fixture = SavedConnection(
  id: 'fixture',
  label: 'Miniserver',
  host: 'fixture.example',
  port: 8642,
  apiKey: 'fixture-key',
);

final _offline = SavedConnection(
  id: 'offline-dashboard',
  label: 'Offline dashboard',
  host: '127.0.0.1',
  port: 8642,
  dashboardPortOverride: 1,
  apiKey: 'test-only',
);

Future<void> _expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget home) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          (_) async => null,
        );
  });

  for (final MapEntry(key: name, value: theme) in _schemes.entries) {
    testWidgets('composer meets Android guidelines ($name)', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        theme,
        ComposerScaffold(host: ComposerHost(text: 'Hello Hermes')),
      );
      await _expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('error state meets Android guidelines ($name)', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, theme, CronScreen(connection: _offline));
      await _expectGuidelines(tester);
      handle.dispose();
    });
  }

  for (final MapEntry(key: name, value: theme) in _schemes.entries) {
    testWidgets('loaded chat meets Android guidelines ($name)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          home: ChatScreen(
            connection: _fixture,
            session: const Session(
              id: 'chat-0',
              title: 'Nightly backup',
              model: 'gpt-oss-20b',
              source: 'gateway',
              messageCount: 3,
              isActive: false,
              preview: '',
              startedAt: 1,
            ),
            testApiClient: ApiClient(
              baseUrl: 'http://fixture.example',
              apiKey: 'fixture-key',
              httpClient: FixtureGateway(),
            ),
            testVoiceComposerAdapter: FakeVoiceComposerAdapter(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('Chats list meets Android guidelines ($name)', (tester) async {
      final handle = tester.ensureSemantics();
      final repository = await fixtureProjects('a11y');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          home: WorkspaceScreen(
            connection: _fixture,
            repositoryFactory: (_) => repository,
            testSessionsHttpClient: FixtureGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chat_bubble_outline).last);
      await tester.pumpAndSettle();
      await _expectGuidelines(tester);
      handle.dispose();
    });
  }

  for (final mode in ['light', 'dark']) {
    testWidgets('Settings meets Android guidelines ($mode)', (tester) async {
      SharedPreferences.setMockInitialValues({'theme_mode': mode});
      final handle = tester.ensureSemantics();
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
      await _expectGuidelines(tester);
      handle.dispose();
    });
  }

  testWidgets('composer actions have TalkBack labels', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _schemes.values.first,
      ComposerScaffold(host: ComposerHost()),
    );
    for (final label in [
      'Choose chat model',
      'Spoken replies',
      'Add attachment',
      'Message',
      'Start voice input',
      'Send message',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    handle.dispose();
  });
}
