import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../expressive/expressive.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_theme.dart';
import '../widgets/settings_group.dart';
import 'chat_icon_settings.dart';
import 'chat_icon_store.dart';
import 'chat_topics.dart';

/// Appearance → Chat icons: a row of sample marks, Letter / On device /
/// By Hermes, Mixed shapes, and in By Hermes mode the relabel row and what
/// is sent.
class ChatIconSettingsSection extends StatelessWidget {
  const ChatIconSettingsSection({
    required this.preferences,
    this.connectionId,
    this.connectionLabel,
    super.key,
  });

  final SharedPreferences preferences;

  /// The connection whose labels Relabel clears; without one the By Hermes
  /// rows that need it are left out.
  final String? connectionId;
  final String? connectionLabel;

  /// Shapes and tones for the sample row, chosen by hand so all five differ.
  static const _sampleStyles = [
    MarkStyle(ExpressiveShape.cookie, MarkTone.primary),
    MarkStyle(ExpressiveShape.flower, MarkTone.tertiary),
    MarkStyle(ExpressiveShape.clover, MarkTone.secondary),
    MarkStyle(ExpressiveShape.burst, MarkTone.primary),
    MarkStyle(ExpressiveShape.pentagon, MarkTone.tertiary),
  ];
  static const _sampleLetters = ['N', 'G', 'P', 'Q', 'T'];
  static const _onDevice = [
    'cloud_sync',
    'water_drop',
    'print',
    'payments',
    'flight',
  ];
  static const _byHermes = [
    'cloud_sync',
    'yard',
    'print',
    'request_quote',
    'luggage',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final store = connectionId == null
        ? null
        : ChatIconStore.forConnection(preferences, connectionId!);
    return ValueListenableBuilder<ChatIconSettings>(
      valueListenable: chatIconSelection,
      builder: (context, settings, _) {
        final mode = settings.mode;
        final blurb = switch (mode) {
          ChatIconMode.letter => l10n.chat_icons_letter_blurb,
          ChatIconMode.onDevice => l10n.chat_icons_on_device_blurb,
          ChatIconMode.hermes => l10n.chat_icons_hermes_blurb,
        };
        return SettingsGroup(
          title: l10n.chat_icons,
          children: [
            Padding(
              padding: const EdgeInsets.all(HermesSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < _sampleStyles.length; i++)
                          _sample(context, settings, i),
                      ],
                    ),
                  ),
                  const SizedBox(height: HermesSpacing.lg),
                  ConnectedButtonGroup<ChatIconMode>(
                    expand: true,
                    height: 48,
                    semanticsLabel: l10n.chat_icons,
                    selected: mode,
                    onSelected: (value) =>
                        ChatIconPreferences(preferences).setMode(value),
                    buttons: [
                      ConnectedButton(
                        value: ChatIconMode.letter,
                        label: l10n.chat_icons_letter,
                        key: const Key('chat-icons-letter'),
                      ),
                      ConnectedButton(
                        value: ChatIconMode.onDevice,
                        label: l10n.chat_icons_on_device,
                        key: const Key('chat-icons-on-device'),
                      ),
                      ConnectedButton(
                        value: ChatIconMode.hermes,
                        label: l10n.chat_icons_by_hermes,
                        key: const Key('chat-icons-hermes'),
                      ),
                    ],
                  ),
                  const SizedBox(height: HermesSpacing.md),
                  Text(
                    blurb,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (mode.showsTopics)
              SwitchListTile(
                key: const Key('chat-icons-mixed-shapes'),
                secondary: const TonalIcon(Icons.category_rounded),
                title: Text(l10n.chat_icons_mixed_shapes),
                subtitle: Text(l10n.chat_icons_mixed_shapes_description),
                value: settings.mixedShapes,
                onChanged: (value) =>
                    ChatIconPreferences(preferences).setMixedShapes(value),
              ),
            if (mode == ChatIconMode.hermes && store != null)
              ListenableBuilder(
                listenable: Listenable.merge([store, store.waiting]),
                builder: (context, _) => ListTile(
                  key: const Key('chat-icons-relabel'),
                  minTileHeight: 72,
                  leading: const TonalIcon(Icons.auto_awesome_rounded),
                  title: Text(l10n.chat_icons_relabel),
                  subtitle: Text(
                    l10n.chat_icons_relabel_status(
                      store.labelledCount,
                      store.waiting.value,
                    ),
                  ),
                  trailing: const Icon(Icons.refresh_rounded),
                  onTap: store.clear,
                ),
              ),
            if (mode == ChatIconMode.hermes)
              Padding(
                padding: const EdgeInsets.all(HermesSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: HermesSpacing.md),
                    Expanded(
                      child: Text(
                        l10n.chat_icons_privacy(connectionLabel ?? 'Hermes'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _sample(BuildContext context, ChatIconSettings settings, int index) {
    if (!settings.mode.showsTopics) {
      return ShapeMark(
        style: MarkStyle.unassigned,
        label: _sampleLetters[index],
        size: 52,
      );
    }
    final names = settings.mode == ChatIconMode.hermes ? _byHermes : _onDevice;
    return ShapeMark(
      style: settings.mixedShapes
          ? _sampleStyles[index]
          : MarkStyle(ExpressiveShape.cookie, _sampleStyles[index].tone),
      icon: chatTopicNamed(names[index])?.icon,
      iconScale: 0.5,
      size: 52,
    );
  }
}
