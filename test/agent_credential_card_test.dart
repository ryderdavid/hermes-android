import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/agent_credential_service.dart';
import 'package:hermes_android/core/services/biometric_gate.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/widgets/agent_credential_card.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemStore implements CredentialStore {
  final Map<String, String> values = <String, String>{};

  @override
  String? readCached(String key) => values[key];

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _FakeAuth implements DeviceAuthenticator {
  _FakeAuth({required this.supported, required this.result});

  final bool supported;
  final bool result;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({required String localizedReason}) async => result;
}

final _conn = SavedConnection(
  id: 'c1',
  label: 'Mac Studio',
  host: '100.110.97.44',
  port: 8642,
  apiKey: 'k',
);

String get _identity =>
    '${_conn.baseUrl}|${_conn.gatewayPrefix ?? ''}|${_conn.desktopGatewayUrl ?? ''}';

Future<AgentCredentialService> _service() async => AgentCredentialService(
  store: _MemStore(),
  preferences: await SharedPreferences.getInstance(),
);

Widget _wrap(AgentCredentialService service, DeviceAuthenticator auth) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: AgentCredentialCard(
        connection: _conn,
        serviceFactory: () async => service,
        gateFactory: () => BiometricGate(authenticator: auth),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('both toggles persist on and survive a reopen', (tester) async {
    final service = await _service();
    await service.saveSudoPassword(_identity, 'pw');
    final auth = _FakeAuth(supported: true, result: true);

    await tester.pumpWidget(_wrap(service, auth));
    await tester.pumpAndSettle();

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(2));
    expect(tester.widget<Switch>(switches.at(0)).value, isFalse);
    expect(tester.widget<Switch>(switches.at(1)).value, isFalse);

    // Flip auto-answer on.
    await tester.tap(switches.at(0));
    await tester.pumpAndSettle();
    expect(
      service.isAutoAnswerEnabled(_identity),
      isTrue,
      reason: 'auto-answer pref must be written when the gate confirms',
    );
    expect(tester.widget<Switch>(switches.at(0)).value, isTrue);

    // Flip fetch on.
    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    expect(
      service.isFetchEnabled(_identity),
      isTrue,
      reason: 'fetch pref must be written when the gate confirms',
    );
    expect(tester.widget<Switch>(switches.at(1)).value, isTrue);

    // Reopen: a brand-new card instance over the same prefs must read on.
    await tester.pumpWidget(_wrap(service, auth));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Switch>(switches.at(0)).value,
      isTrue,
      reason: 'auto-answer must still be on after reopen',
    );
    expect(
      tester.widget<Switch>(switches.at(1)).value,
      isTrue,
      reason: 'fetch must still be on after reopen',
    );

    // Flip both off; they must persist off too.
    await tester.tap(switches.at(0));
    await tester.pumpAndSettle();
    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    expect(service.isAutoAnswerEnabled(_identity), isFalse);
    expect(service.isFetchEnabled(_identity), isFalse);
  });

  testWidgets('toggles do not turn on when the gate refuses', (tester) async {
    final service = await _service();
    await service.saveSudoPassword(_identity, 'pw');
    final auth = _FakeAuth(supported: true, result: false);

    await tester.pumpWidget(_wrap(service, auth));
    await tester.pumpAndSettle();

    final switches = find.byType(Switch);
    await tester.tap(switches.at(0));
    await tester.pumpAndSettle();
    expect(service.isAutoAnswerEnabled(_identity), isFalse);
    expect(tester.widget<Switch>(switches.at(0)).value, isFalse);
    expect(
      find.text('Enable cancelled — the toggle stays off.'),
      findsOneWidget,
      reason: 'a refused gate must say why the toggle did not stick',
    );

    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    expect(service.isFetchEnabled(_identity), isFalse);
    expect(tester.widget<Switch>(switches.at(1)).value, isFalse);
  });
}
