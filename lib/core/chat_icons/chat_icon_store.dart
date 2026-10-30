import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_topics.dart';

/// The icon Hermes chose for one chat, and the title it chose it for.
@immutable
class ChatIconLabel {
  const ChatIconLabel(this.icon, this.titleHash);

  final String icon;
  final int titleHash;
}

/// A stable 32-bit FNV-1a hash of a trimmed title: a label for a title the
/// chat no longer has is stale (design D4).
int chatTitleHash(String title) {
  var hash = 0x811c9dc5;
  for (final unit in title.trim().codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// Hermes's icon labels for one connection, kept on the device.
///
/// One store per connection and preferences instance ([forConnection]), so
/// Home, Chats and an open chat read and hear about the same labels.
class ChatIconStore extends ChangeNotifier {
  ChatIconStore(this._preferences, this.connectionId) {
    _load();
  }

  static final Map<(SharedPreferences, String), ChatIconStore> _cache = {};

  /// The shared store for [connectionId].
  static ChatIconStore forConnection(
    SharedPreferences preferences,
    String connectionId,
  ) => _cache.putIfAbsent((
    preferences,
    connectionId,
  ), () => ChatIconStore(preferences, connectionId));

  @visibleForTesting
  static void resetCache() => _cache.clear();

  final SharedPreferences _preferences;
  final String connectionId;
  final Map<String, ChatIconLabel> _labels = {};

  /// Chats already sent to Hermes under a title this run, labelled or not,
  /// so a chat Hermes left out is not sent again on every rebuild.
  final Map<String, int> _asked = {};

  /// Labels in flight are announced here, so the Appearance page can say how
  /// many chats are still waiting; set by the connection's labeller.
  final ValueNotifier<int> waiting = ValueNotifier(0);

  String get _key => 'chat_icons_v1:$connectionId';

  int get labelledCount => _labels.length;

  void _load() {
    final raw = _preferences.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((id, value) {
        if (id is! String || value is! Map) return;
        final icon = value['i'];
        final hash = value['h'];
        if (icon is String && hash is int && chatTopicNamed(icon) != null) {
          _labels[id] = ChatIconLabel(icon, hash);
        }
      });
    } on FormatException {
      // A corrupt entry only costs the labels; Hermes will be asked again.
    }
  }

  /// Hermes's icon for [sessionId] while its title is still [title].
  ChatTopic? topicFor(String sessionId, String title) {
    final label = _labels[sessionId];
    if (label == null || label.titleHash != chatTitleHash(title)) return null;
    return chatTopicNamed(label.icon);
  }

  /// Whether [sessionId] has a label that is current for [title].
  bool isLabelled(String sessionId, String title) =>
      topicFor(sessionId, title) != null;

  void markAsked(String sessionId, String title) =>
      _asked[sessionId] = chatTitleHash(title);

  bool wasAsked(String sessionId, String title) =>
      _asked[sessionId] == chatTitleHash(title);

  Future<void> putAll(Map<String, ({String icon, String title})> labels) async {
    if (labels.isEmpty) return;
    labels.forEach((id, label) {
      if (chatTopicNamed(label.icon) == null) return;
      _labels[id] = ChatIconLabel(label.icon, chatTitleHash(label.title));
    });
    notifyListeners();
    await _save();
  }

  /// Forgets every label, so Hermes is asked again as chats come into view.
  Future<void> clear() async {
    _labels.clear();
    _asked.clear();
    notifyListeners();
    await _preferences.remove(_key);
  }

  Future<void> _save() => _preferences.setString(
    _key,
    jsonEncode({
      for (final entry in _labels.entries)
        entry.key: {'i': entry.value.icon, 'h': entry.value.titleHash},
    }),
  );

  @override
  void dispose() {
    waiting.dispose();
    super.dispose();
  }
}
