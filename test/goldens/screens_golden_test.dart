import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/screens/workspace_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/widgets/hermes_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_voice_composer_adapter.dart';
import '../support/fixture_gateway.dart';
import 'golden_harness.dart';

SavedConnection _connection(String id) => SavedConnection(
  id: id,
  label: 'Miniserver',
  host: 'fixture.example',
  port: 8642,
  apiKey: 'fixture-key',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // ChatScreen asks image_picker for a lost capture on start.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          (_) async => null,
        );
  });

  for (final variant in goldenMatrix) {
    for (final pane in [HermesDestination.home, HermesDestination.chats]) {
      testWidgets('${pane.name} ${variant.name}', (tester) async {
        final repository = await fixtureProjects('golden-${pane.name}');
        await pumpGolden(
          tester,
          WorkspaceScreen(
            connection: _connection('golden-${pane.name}'),
            repositoryFactory: (_) => repository,
            testSessionsHttpClient: FixtureGateway(),
          ),
          variant: variant,
          settle: false,
        );
        if (pane != HermesDestination.home) {
          await tester.tap(find.byIcon(Icons.chat_bubble_outline).last);
        }
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        await matchGolden(tester, 'screens/${pane.name}_${variant.name}.png');
      });
    }

    testWidgets('chat ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        ChatScreen(
          connection: _connection('golden-chat'),
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
        variant: variant,
        settle: false,
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await matchGolden(tester, 'screens/chat_${variant.name}.png');
    });
  }
}
