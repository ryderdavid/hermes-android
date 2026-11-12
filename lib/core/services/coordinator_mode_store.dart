import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists coordinator mode per connection and chat, plus the default that
/// new chats start with.
///
/// The phone's value is the source of truth for a chat: it is sent to the
/// gateway whenever the chat binds its session. Keys follow
/// `ChatModelOverrideStore`: the namespace is encoded so gateway URLs do not
/// leak into preference keys, while identical session ids on two connections
/// still cannot collide.
class CoordinatorModeStore {
  /// Per-chat keys start with this; the backup carries the whole prefix.
  static const keyPrefix = 'coordinator_mode.';

  /// "New chats use coordinator mode".
  static const newChatsDefaultKey = 'coordinator_mode_new_chats';

  final SharedPreferences _preferences;

  CoordinatorModeStore(this._preferences);

  static Future<CoordinatorModeStore> open() async {
    return CoordinatorModeStore(await SharedPreferences.getInstance());
  }

  /// The user's choice for this chat, or `null` when they never made one.
  bool? read({required String connectionIdentity, required String sessionId}) {
    return _preferences.getBool(_key(connectionIdentity, sessionId));
  }

  Future<void> save({
    required String connectionIdentity,
    required String sessionId,
    required bool enabled,
  }) async {
    await _preferences.setBool(_key(connectionIdentity, sessionId), enabled);
  }

  /// Whether a chat with no choice of its own starts in coordinator mode.
  /// Only a new chat takes the default; an existing chat stays off.
  bool get newChatsDefault => _preferences.getBool(newChatsDefaultKey) ?? false;

  Future<void> setNewChatsDefault(bool enabled) async {
    await _preferences.setBool(newChatsDefaultKey, enabled);
    coordinatorNewChatsDefault.value = enabled;
  }

  /// The mode a chat opens in: its own stored choice, else the default when
  /// it is a new chat, else off.
  bool resolve({
    required String connectionIdentity,
    required String sessionId,
    required bool isNewChat,
  }) {
    return read(connectionIdentity: connectionIdentity, sessionId: sessionId) ??
        (isNewChat && newChatsDefault);
  }

  static String _key(String connectionIdentity, String sessionId) {
    final namespace = base64Url
        .encode(utf8.encode('$connectionIdentity\u0000$sessionId'))
        .replaceAll('=', '');
    return '$keyPrefix$namespace';
  }
}

/// The live "new chats" default, so the Settings switch follows a restore.
final ValueNotifier<bool> coordinatorNewChatsDefault = ValueNotifier(false);
