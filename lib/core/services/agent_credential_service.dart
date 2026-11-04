// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connection_manager.dart' show CredentialStore;

/// One recorded automatic answer to a gateway `sudo` request.
///
/// Audit entries deliberately never contain the credential value: only when,
/// which connection, and which request were involved.
class AgentSudoAuditEntry {
  final int timestampMillis;
  final String connectionLabel;
  final String requestId;

  const AgentSudoAuditEntry({
    required this.timestampMillis,
    required this.connectionLabel,
    required this.requestId,
  });

  Map<String, dynamic> toJson() => {
    'ts': timestampMillis,
    'connection': connectionLabel,
    'request': requestId,
  };

  static AgentSudoAuditEntry? fromJson(Map<String, dynamic> json) {
    final ts = json['ts'];
    final request = json['request']?.toString().trim() ?? '';
    if (ts is! int || request.isEmpty) return null;
    return AgentSudoAuditEntry(
      timestampMillis: ts,
      connectionLabel: json['connection']?.toString() ?? '',
      requestId: request,
    );
  }
}

/// Protected storage and consent state for the agent SUDO password.
///
/// The SUDO password (the Mac admin password) is stored through the
/// [CredentialStore] abstraction, backed in production by Android Keystore via
/// `flutter_secure_storage` in a namespace dedicated to agent credentials, so
/// wiping connection API keys never touches it and vice versa. The value is
/// never written to SharedPreferences, never logged, and never exposed in UI;
/// it is only released as the answer to a `sudo` request on the connection it
/// was saved for.
///
/// Reads fail closed: a Keystore error is reported as "absent" so a corrupt or
/// unavailable entry can never be answered with a partial or plaintext value.
class AgentCredentialService {
  static const _sudoKeyPrefix = 'sudo_password';
  static const _autoAnswerKeyPrefix = 'agent_auto_answer_sudo';
  static const _auditKey = 'agent_sudo_audit';
  static const int auditCapacity = 200;

  final CredentialStore _store;
  final SharedPreferences _preferences;

  AgentCredentialService({
    required CredentialStore store,
    required SharedPreferences preferences,
  }) : _store = store,
       _preferences = preferences;

  /// Production instance: Keystore-backed store in its own namespace plus the
  /// regular preferences for the non-secret toggle and audit trail.
  static Future<AgentCredentialService> open() async {
    const androidOptions = AndroidOptions(
      // Fail closed: a broken Keystore entry is wiped rather than trusted,
      // and the SUDO password must never migrate into device backups.
      resetOnError: true,
      migrateWithBackup: false,
      storageNamespace: 'hermes_android_agent_credentials',
    );
    return AgentCredentialService(
      store: _KeystoreCredentialStore(androidOptions),
      preferences: await SharedPreferences.getInstance(),
    );
  }

  static String _sudoKey(String connectionIdentity) =>
      '$_sudoKeyPrefix|$connectionIdentity';

  static String _autoAnswerKey(String connectionIdentity) =>
      '$_autoAnswerKeyPrefix|$connectionIdentity';

  /// Reads the stored SUDO password, or null when absent or unreadable.
  Future<String?> readSudoPassword(String connectionIdentity) async {
    try {
      final value = await _store.read(_sudoKey(connectionIdentity));
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      // Fail closed: never answer with a value we could not read cleanly.
      return null;
    }
  }

  Future<bool> hasSudoPassword(String connectionIdentity) async =>
      await readSudoPassword(connectionIdentity) != null;

  Future<void> saveSudoPassword(
    String connectionIdentity,
    String password,
  ) async {
    final trimmed = password.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('The SUDO password must not be empty');
    }
    await _store.write(_sudoKey(connectionIdentity), trimmed);
  }

  Future<void> clearSudoPassword(String connectionIdentity) async {
    await _store.delete(_sudoKey(connectionIdentity));
  }

  /// Whether sudo requests on this connection may be answered automatically.
  /// Defaults to off and is a plain (non-secret) preference.
  bool isAutoAnswerEnabled(String connectionIdentity) =>
      _preferences.getBool(_autoAnswerKey(connectionIdentity)) ?? false;

  Future<void> setAutoAnswerEnabled(
    String connectionIdentity,
    bool enabled,
  ) async {
    await _preferences.setBool(_autoAnswerKey(connectionIdentity), enabled);
  }

  /// True only when both the toggle is on and a credential is readable.
  Future<bool> canAutoAnswer(String connectionIdentity) async =>
      isAutoAnswerEnabled(connectionIdentity) &&
      await hasSudoPassword(connectionIdentity);

  Future<void> recordAutoAnswer({
    required String connectionLabel,
    required String requestId,
  }) async {
    final raw = _preferences.getString(_auditKey);
    final entries = <AgentSudoAuditEntry>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final entry = AgentSudoAuditEntry.fromJson(item);
              if (entry != null) entries.add(entry);
            }
          }
        }
      } catch (_) {
        // A corrupt audit log is discarded, never trusted.
      }
    }
    entries.add(
      AgentSudoAuditEntry(
        timestampMillis: DateTime.now().millisecondsSinceEpoch,
        connectionLabel: connectionLabel,
        requestId: requestId,
      ),
    );
    final capped = entries.length > auditCapacity
        ? entries.sublist(entries.length - auditCapacity)
        : entries;
    await _preferences.setString(
      _auditKey,
      jsonEncode(capped.map((e) => e.toJson()).toList()),
    );
  }

  List<AgentSudoAuditEntry> auditEntries() {
    final raw = _preferences.getString(_auditKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>)
            ...[
              AgentSudoAuditEntry.fromJson(item),
            ].whereType<AgentSudoAuditEntry>(),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// [CredentialStore] backed by Android Keystore in the agent-credential
/// namespace. Kept separate from [FlutterSecureCredentialStore] so the
/// connection namespace and this one can never be wiped together by accident.
class _KeystoreCredentialStore implements CredentialStore {
  final FlutterSecureStorage _storage;

  _KeystoreCredentialStore(AndroidOptions androidOptions)
    : _storage = FlutterSecureStorage(aOptions: androidOptions);

  @override
  String? readCached(String key) => null;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
