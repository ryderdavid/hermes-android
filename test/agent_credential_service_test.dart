import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/agent_credential_service.dart';
import 'package:hermes_android/core/services/biometric_gate.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryCredentialStore implements CredentialStore {
  final Map<String, String> values = <String, String>{};
  bool throwOnRead = false;

  @override
  String? readCached(String key) => values[key];

  @override
  Future<String?> read(String key) async {
    if (throwOnRead) throw Exception('keystore unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _FakeAuthenticator implements DeviceAuthenticator {
  bool supported;
  bool result;
  bool throwOnAuthenticate;

  _FakeAuthenticator({
    this.supported = true,
    this.result = true,
    this.throwOnAuthenticate = false,
  });

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    if (throwOnAuthenticate) throw Exception('platform error');
    return result;
  }
}

AgentCredentialService _service(
  CredentialStore store,
  SharedPreferences prefs,
) => AgentCredentialService(store: store, preferences: prefs);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AgentCredentialService SUDO password storage', () {
    test('save then read returns the trimmed password', () async {
      final store = _MemoryCredentialStore();
      final prefs = await SharedPreferences.getInstance();
      final service = _service(store, prefs);

      await service.saveSudoPassword('conn-a', '  s3cret  ');

      expect(await service.hasSudoPassword('conn-a'), isTrue);
      expect(await service.readSudoPassword('conn-a'), 's3cret');
    });

    test('credentials are isolated per connection', () async {
      final store = _MemoryCredentialStore();
      final prefs = await SharedPreferences.getInstance();
      final service = _service(store, prefs);

      await service.saveSudoPassword('conn-a', 'pw-a');

      expect(await service.hasSudoPassword('conn-b'), isFalse);
      expect(await service.readSudoPassword('conn-b'), isNull);
    });

    test('clear removes the password and disables auto-answer', () async {
      final store = _MemoryCredentialStore();
      final prefs = await SharedPreferences.getInstance();
      final service = _service(store, prefs);

      await service.saveSudoPassword('conn-a', 'pw-a');
      await service.setAutoAnswerEnabled('conn-a', true);
      expect(await service.canAutoAnswer('conn-a'), isTrue);

      await service.clearSudoPassword('conn-a');

      expect(await service.hasSudoPassword('conn-a'), isFalse);
      expect(await service.canAutoAnswer('conn-a'), isFalse);
    });

    test('reads fail closed when the keystore errors', () async {
      final store = _MemoryCredentialStore();
      final prefs = await SharedPreferences.getInstance();
      final service = _service(store, prefs);

      await service.saveSudoPassword('conn-a', 'pw-a');
      await service.setAutoAnswerEnabled('conn-a', true);
      store.throwOnRead = true;

      expect(await service.readSudoPassword('conn-a'), isNull);
      expect(await service.hasSudoPassword('conn-a'), isFalse);
      expect(await service.canAutoAnswer('conn-a'), isFalse);
    });

    test('saving an empty password is rejected', () async {
      final store = _MemoryCredentialStore();
      final prefs = await SharedPreferences.getInstance();
      final service = _service(store, prefs);

      expect(
        () => service.saveSudoPassword('conn-a', '   '),
        throwsArgumentError,
      );
    });
  });

  group('AgentCredentialService auto-answer preference', () {
    test('auto-answer defaults to off', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = _service(_MemoryCredentialStore(), prefs);

      expect(service.isAutoAnswerEnabled('conn-a'), isFalse);
      expect(await service.canAutoAnswer('conn-a'), isFalse);
    });

    test(
      'canAutoAnswer requires both the toggle and a stored password',
      () async {
        final store = _MemoryCredentialStore();
        final prefs = await SharedPreferences.getInstance();
        final service = _service(store, prefs);

        await service.setAutoAnswerEnabled('conn-a', true);
        expect(await service.canAutoAnswer('conn-a'), isFalse);

        await service.saveSudoPassword('conn-a', 'pw-a');
        expect(await service.canAutoAnswer('conn-a'), isTrue);

        await service.setAutoAnswerEnabled('conn-a', false);
        expect(await service.canAutoAnswer('conn-a'), isFalse);
      },
    );
  });

  group('AgentCredentialService audit trail', () {
    test('records entries without the credential value', () async {
      final store = _MemoryCredentialStore();
      final prefs = await SharedPreferences.getInstance();
      final service = _service(store, prefs);

      await service.saveSudoPassword('conn-a', 's3cret-value');
      await service.recordAutoAnswer(
        connectionLabel: 'Mac Studio',
        requestId: 'req-1',
      );

      final entries = service.auditEntries();
      expect(entries, hasLength(1));
      expect(entries.single.connectionLabel, 'Mac Studio');
      expect(entries.single.requestId, 'req-1');
      expect(entries.single.timestampMillis, greaterThan(0));

      final raw = prefs.getString('agent_sudo_audit');
      expect(raw, isNotNull);
      expect(raw, isNot(contains('s3cret-value')));
      // The keystore holds the value, the audit log must not.
      expect(store.values.values.join(','), contains('s3cret-value'));
    });

    test('caps the audit log at 200 entries', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = _service(_MemoryCredentialStore(), prefs);

      for (var i = 0; i < 205; i++) {
        await service.recordAutoAnswer(
          connectionLabel: 'Mac Studio',
          requestId: 'req-$i',
        );
      }

      final entries = service.auditEntries();
      expect(entries, hasLength(AgentCredentialService.auditCapacity));
      expect(entries.last.requestId, 'req-204');
    });

    test('a corrupt audit log reads as empty', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('agent_sudo_audit', '{not json');
      final service = _service(_MemoryCredentialStore(), prefs);

      expect(service.auditEntries(), isEmpty);
    });
  });

  group('BiometricGate', () {
    test(
      'authenticates when the device supports it and the user confirms',
      () async {
        final gate = BiometricGate(
          authenticator: _FakeAuthenticator(supported: true, result: true),
        );
        expect(await gate.isAvailable(), isTrue);
        expect(await gate.authenticate(localizedReason: 'r'), isTrue);
      },
    );

    test('fails closed when no biometric or PIN exists', () async {
      final gate = BiometricGate(
        authenticator: _FakeAuthenticator(supported: false),
      );
      expect(await gate.isAvailable(), isFalse);
      expect(await gate.authenticate(localizedReason: 'r'), isFalse);
    });

    test('fails closed when the user cancels or the platform errors', () async {
      final cancelled = BiometricGate(
        authenticator: _FakeAuthenticator(result: false),
      );
      expect(await cancelled.authenticate(localizedReason: 'r'), isFalse);

      final erroring = BiometricGate(
        authenticator: _FakeAuthenticator(throwOnAuthenticate: true),
      );
      expect(await erroring.authenticate(localizedReason: 'r'), isFalse);
    });
  });
}
