import 'package:flutter/material.dart';

import '../expressive/shapes.dart';
import 'chat_icon_labeller.dart';
import 'chat_icon_settings.dart';
import 'chat_icon_store.dart';
import 'chat_topics.dart';

/// Hands a connection's chat icon labels, and the labeller that fills them,
/// to every [ChatMark] below it.
class ChatIconScope extends InheritedWidget {
  const ChatIconScope({
    required this.store,
    this.labeller,
    required super.child,
    super.key,
  });

  final ChatIconStore store;

  /// Null where nothing may ask Hermes (an open chat reads labels only).
  final ChatIconLabeller? labeller;

  static ChatIconScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatIconScope>();

  @override
  bool updateShouldNotify(ChatIconScope oldWidget) =>
      store != oldWidget.store || labeller != oldWidget.labeller;
}

/// The shape and tone of chat [sessionId]'s topic mark: picked from its id,
/// so it is the same everywhere and never changes (design D5).
MarkStyle chatMarkStyle(String sessionId, {bool mixedShapes = true}) {
  var hash = 0;
  for (final unit in sessionId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  // Mix the bits, so ids that differ only at the end (session-1,
  // session-2) still land on different shapes and tones.
  hash ^= hash >> 16;
  hash = (hash * 0x45d9f3b) & 0x7fffffff;
  hash ^= hash >> 16;
  const shapes = ExpressiveShape.chatMarks;
  return MarkStyle(
    mixedShapes ? shapes[hash % shapes.length] : ExpressiveShape.cookie,
    MarkTone.values[(hash >> 8) % MarkTone.values.length],
  );
}

/// A chat's mark in lists and its app bar.
///
/// With Chat icons set to Letter it is the [letterStyle] mark it always was.
/// Otherwise it is the chat's own shape holding its topic icon: Hermes's
/// label when there is one, else the on-device match, else the title's
/// first letter.
class ChatMark extends StatelessWidget {
  const ChatMark({
    required this.sessionId,
    required this.title,
    required this.letterStyle,
    this.letterLabel,
    this.letterIcon,
    this.badge,
    this.size = 44,
    super.key,
  });

  final String sessionId;
  final String title;
  final MarkStyle letterStyle;

  /// What the Letter mark shows; defaults to [title].
  final String? letterLabel;
  final IconData? letterIcon;

  /// A small state glyph (a pin) shown on the corner of a topic mark, where
  /// the icon can no longer carry it.
  final IconData? badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChatIconSettings>(
      valueListenable: chatIconSelection,
      builder: (context, settings, _) {
        if (!settings.mode.showsTopics) {
          return ShapeMark(
            style: letterStyle,
            label: letterLabel ?? title,
            icon: letterIcon,
            size: size,
          );
        }
        final scope = ChatIconScope.maybeOf(context);
        Widget topicMark() {
          ChatTopic? topic;
          if (settings.mode == ChatIconMode.hermes && scope != null) {
            topic = scope.store.topicFor(sessionId, title);
            if (topic == null) scope.labeller?.request(sessionId, title);
          }
          topic ??= matchChatTopic(title);
          return _withBadge(
            context,
            ShapeMark(
              style: chatMarkStyle(
                sessionId,
                mixedShapes: settings.mixedShapes,
              ),
              label: title,
              icon: topic?.icon,
              iconScale: 0.5,
              size: size,
            ),
          );
        }

        if (scope == null) return topicMark();
        return ListenableBuilder(
          listenable: scope.store,
          builder: (context, _) => topicMark(),
        );
      },
    );
  }

  Widget _withBadge(BuildContext context, Widget mark) {
    final badge = this.badge;
    if (badge == null) return mark;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          mark,
          Positioned(
            right: -3,
            bottom: -3,
            child: ExcludeSemantics(
              child: Container(
                width: size * 0.42,
                height: size * 0.42,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(badge, size: size * 0.24, color: scheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
