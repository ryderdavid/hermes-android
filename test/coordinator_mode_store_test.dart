import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/config_backup_service.dart';
import 'package:hermes_android/core/services/coordinator_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    coordinatorNewChatsDefault.value = false;
  });

  test('a chat with no choice of its own reads as unset', () async {
    final store = await CoordinatorModeStore.open();

    expect(
      store.read(connectionIdentity: 'conn-a', sessionId: 'chat-1'),
      isNull,
    );
    expect(
      store.resolve(
        connectionIdentity: 'conn-a',
        sessionId: 'chat-1',
        isNewChat: false,
      ),
      isFalse,
    );
  });

  test('persists the choice per chat across a restart', () async {
    final store = await CoordinatorModeStore.open();
    await store.save(
      connectionIdentity: 'conn-a',
      sessionId: 'chat-1',
      enabled: true,
    );

    // A new store over the same preferences is the app after a restart.
    final reopened = await CoordinatorModeStore.open();
    expect(
      reopened.read(connectionIdentity: 'conn-a', sessionId: 'chat-1'),
      isTrue,
    );
    expect(
      reopened.resolve(
        connectionIdentity: 'conn-a',
        sessionId: 'chat-1',
        isNewChat: false,
      ),
      isTrue,
    );
  });

  test('does not leak into another chat or another connection', () async {
    final store = await CoordinatorModeStore.open();
    await store.save(
      connectionIdentity: 'conn-a',
      sessionId: 'chat-1',
      enabled: true,
    );

    expect(
      store.read(connectionIdentity: 'conn-a', sessionId: 'chat-2'),
      isNull,
    );
    expect(
      store.read(connectionIdentity: 'conn-b', sessionId: 'chat-1'),
      isNull,
    );
  });

  test('turning it off is remembered as off, not as unset', () async {
    final store = await CoordinatorModeStore.open();
    await store.setNewChatsDefault(true);
    await store.save(
      connectionIdentity: 'conn-a',
      sessionId: 'chat-1',
      enabled: false,
    );

    expect(
      store.resolve(
        connectionIdentity: 'conn-a',
        sessionId: 'chat-1',
        isNewChat: true,
      ),
      isFalse,
    );
  });

  test('new chats start off unless the default is on', () async {
    final store = await CoordinatorModeStore.open();
    expect(store.newChatsDefault, isFalse);
    expect(
      store.resolve(
        connectionIdentity: 'conn-a',
        sessionId: 'draft-1',
        isNewChat: true,
      ),
      isFalse,
    );

    await store.setNewChatsDefault(true);

    expect(coordinatorNewChatsDefault.value, isTrue);
    expect(
      store.resolve(
        connectionIdentity: 'conn-a',
        sessionId: 'draft-1',
        isNewChat: true,
      ),
      isTrue,
    );
    // The default is for new chats only.
    expect(
      store.resolve(
        connectionIdentity: 'conn-a',
        sessionId: 'old-chat',
        isNewChat: false,
      ),
      isFalse,
    );
  });

  test('preference keys do not carry the gateway URL', () async {
    final store = await CoordinatorModeStore.open();
    await store.save(
      connectionIdentity: 'https://gateway.example|/api|',
      sessionId: 'chat-1',
      enabled: true,
    );

    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().single;
    expect(key, startsWith(CoordinatorModeStore.keyPrefix));
    expect(key, isNot(contains('gateway.example')));
  });

  test('both the per-chat keys and the default are in the backup', () async {
    final store = await CoordinatorModeStore.open();
    await store.save(
      connectionIdentity: 'conn-a',
      sessionId: 'chat-1',
      enabled: true,
    );
    await store.setNewChatsDefault(true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), hasLength(2));
    for (final key in prefs.getKeys()) {
      expect(ConfigBackupService.isBackedUpKey(key), isTrue, reason: key);
    }
  });
}
