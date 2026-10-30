import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How a chat is drawn in lists and in its app bar.
enum ChatIconMode {
  /// The first letter of the title on one shared shape, as before.
  letter('letter'),

  /// A topic icon matched to the title on the device.
  onDevice('on_device'),

  /// A topic icon chosen by Hermes, with the on-device match until it answers.
  hermes('hermes');

  const ChatIconMode(this.storageValue);

  final String storageValue;

  bool get showsTopics => this != ChatIconMode.letter;

  static ChatIconMode fromStorage(String? value) => ChatIconMode.values
      .firstWhere((m) => m.storageValue == value, orElse: () => letter);
}

@immutable
class ChatIconSettings {
  const ChatIconSettings({
    this.mode = ChatIconMode.letter,
    this.mixedShapes = true,
  });

  final ChatIconMode mode;

  /// Each chat gets a shape picked from its id; off, every chat is a cookie.
  final bool mixedShapes;

  ChatIconSettings copyWith({ChatIconMode? mode, bool? mixedShapes}) =>
      ChatIconSettings(
        mode: mode ?? this.mode,
        mixedShapes: mixedShapes ?? this.mixedShapes,
      );

  @override
  bool operator ==(Object other) =>
      other is ChatIconSettings &&
      other.mode == mode &&
      other.mixedShapes == mixedShapes;

  @override
  int get hashCode => Object.hash(mode, mixedShapes);
}

/// Current chat icon settings, broadcast so every list redraws the moment the
/// Appearance page changes them.
final ValueNotifier<ChatIconSettings> chatIconSelection = ValueNotifier(
  const ChatIconSettings(),
);

/// Reads and writes [ChatIconSettings]; both directions keep
/// [chatIconSelection] in sync.
class ChatIconPreferences {
  ChatIconPreferences(this._preferences);

  static const modeKey = 'chat_icon_mode';
  static const mixedShapesKey = 'chat_icon_mixed_shapes';

  final SharedPreferences _preferences;

  ChatIconSettings read() {
    final settings = ChatIconSettings(
      mode: ChatIconMode.fromStorage(_preferences.getString(modeKey)),
      mixedShapes: _preferences.getBool(mixedShapesKey) ?? true,
    );
    chatIconSelection.value = settings;
    return settings;
  }

  Future<void> setMode(ChatIconMode mode) async {
    chatIconSelection.value = chatIconSelection.value.copyWith(mode: mode);
    await _preferences.setString(modeKey, mode.storageValue);
  }

  Future<void> setMixedShapes(bool value) async {
    chatIconSelection.value = chatIconSelection.value.copyWith(
      mixedShapes: value,
    );
    await _preferences.setBool(mixedShapesKey, value);
  }
}
