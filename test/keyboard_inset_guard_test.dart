import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/widgets/keyboard_inset_guard.dart';
import 'package:hermes_android/l10n/app_localizations.dart';

import 'support/fake_voice_composer_adapter.dart';

/// A root that mirrors main.dart: the guard owns the MediaQuery below it.
Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => KeyboardInsetGuard(child: child!),
  home: home,
);

void main() {
  testWidgets('a stuck keyboard inset is clamped when no field is focused', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox.shrink()),
              const TextField(key: Key('field'), autofocus: true),
              const SizedBox(key: Key('dock'), height: 48),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Sanity: the field starts focused, so an inset is honored.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('dock'))).bottom, 892 - 300);

    // The IME is dismissed (platform fails to clear the inset) and focus
    // leaves the field: the guard must clamp the stale inset.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('dock'))).bottom, 892);

    // The inset is still "stuck" at the platform level; re-focusing an
    // editable makes the IME area live again.
    await tester.tap(find.byKey(const Key('field')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('dock'))).bottom, 892 - 300);
  });

  testWidgets('ChatScreen: composer returns to the bottom when a stuck inset '
      'outlives focus', (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'verbose_mode': false});
    const picker = MethodChannel('plugins.flutter.io/image_picker');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(picker, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(picker, null),
    );
    await tester.pumpWidget(
      _app(
        ChatScreen(
          connection: SavedConnection(
            id: 'inset-guard-fixture',
            label: 'Inset fixture',
            host: 'fixture.invalid',
            port: 8000,
            apiKey: 'probe-key',
          ),
          session: const Session(
            id: 's1',
            title: 'Chat',
            model: 'fixture',
            source: 'test',
            messageCount: 0,
            isActive: false,
            preview: '',
            startedAt: 1,
          ),
          testVoiceComposerAdapter: FakeVoiceComposerAdapter(),
          testApiClient: ApiClient(
            baseUrl: 'https://fixture.invalid',
            apiKey: 'probe-key',
            httpClient: MockClient(
              (_) async => http.Response(jsonEncode({'data': []}), 200),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bar = find.byKey(const Key('chat-input-bar'));
    // Keyboard open + composer focused: the bar rides above the IME.
    await tester.tap(find.byKey(const Key('chat-message-composer')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    await tester.pumpAndSettle();
    expect(tester.getRect(bar).bottom, 892 - 340);

    // IME dismissed but the platform inset stays stuck; focus leaves the
    // composer (tap on the transcript). The bar must dock at the bottom.
    await tester.tap(find.byType(Scaffold).first);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(tester.getRect(bar).bottom, 892);
    expect(tester.takeException(), isNull);
  });
}
