import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../chat_icons/chat_icon_settings_section.dart';
import '../expressive/expressive.dart';
import '../l10n/l10n.dart';
import '../services/appearance_preferences.dart';
import '../theme/hermes_theme.dart';
import '../widgets/appearance_color_picker.dart';
import '../widgets/chat_density_settings_card.dart';
import '../widgets/settings_group.dart';
import '../widgets/text_size_settings_card.dart';

/// Appearance, as its own page like Pixel's "Wallpaper & style": a live
/// preview, the theme as a connected button group, the palette swatches and
/// pure black, then text size and chat density. Everything here is stored on
/// the device, so the page works without the dashboard.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({this.connectionId, this.connectionLabel, super.key});

  /// The connection Settings was opened for: Chat icons' relabel row and
  /// privacy note name it.
  final String? connectionId;
  final String? connectionLabel;

  @override
  Widget build(BuildContext context) {
    final app = context.findAncestorStateOfType<HermesAppState>()!;
    final prefs = app.widget.connManager.prefs;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HermesSpacing.lg,
          0,
          HermesSpacing.lg,
          HermesSpacing.xl,
        ),
        children: [
          LargeHeader(
            title: l10n.appearance,
            padding: const EdgeInsets.fromLTRB(4, 0, 4, HermesSpacing.lg),
          ),
          const AppearancePreview(),
          const SizedBox(height: HermesSpacing.xl),
          SettingsGroup(
            title: l10n.theme_label,
            children: const [ThemeModeSelector()],
          ),
          // The picker's own first row names the color, so no group title.
          SettingsGroup(
            children: [
              AppearanceColorPicker(preferences: AppearancePreferences(prefs)),
            ],
          ),
          ChatIconSettingsSection(
            preferences: prefs,
            connectionId: connectionId,
            connectionLabel: connectionLabel,
          ),
          SettingsGroup(
            title: l10n.text_and_chats,
            children: [
              TextSizeSettingsCard(
                preferences: prefs,
                onChanged: app.setTextSizePreference,
              ),
              ChatDensitySettingsCard(preferences: prefs),
            ],
          ),
        ],
      ),
    );
  }
}

/// System, Light and Dark as a full-width connected button group.
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<AppearanceSettings>(
      valueListenable: appearanceSelection,
      builder: (context, appearance, _) => Padding(
        padding: const EdgeInsets.all(HermesSpacing.lg),
        child: ConnectedButtonGroup<ThemeMode>(
          expand: true,
          height: 48,
          semanticsLabel: l10n.theme_label,
          selected: appearance.themeMode,
          onSelected: (mode) async => AppearancePreferences(
            await SharedPreferences.getInstance(),
          ).setThemeMode(mode),
          buttons: [
            ConnectedButton(
              value: ThemeMode.system,
              label: l10n.system,
              icon: Icons.brightness_auto_outlined,
              key: const Key('theme-mode-system'),
            ),
            ConnectedButton(
              value: ThemeMode.light,
              label: l10n.light,
              icon: Icons.light_mode_outlined,
              key: const Key('theme-mode-light'),
            ),
            ConnectedButton(
              value: ThemeMode.dark,
              label: l10n.dark,
              icon: Icons.dark_mode_outlined,
              key: const Key('theme-mode-dark'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small chat in the current theme: one of your bubbles and one Hermes
/// reply, so color and text size changes show at once.
class AppearancePreview extends StatelessWidget {
  const AppearancePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    return Semantics(
      container: true,
      label: l10n.preview_label,
      child: Container(
        padding: const EdgeInsets.all(HermesSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(HermesRadius.xlPlus),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HermesSpacing.lg,
                  vertical: HermesSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(HermesRadius.xl),
                    topRight: Radius.circular(HermesRadius.xl),
                    bottomLeft: Radius.circular(HermesRadius.xl),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Text(
                  l10n.appearance_preview_question,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: HermesSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShapeMark(
                  style: MarkStyle(ExpressiveShape.cookie, MarkTone.tertiary),
                  icon: Icons.auto_awesome,
                  size: 32,
                ),
                const SizedBox(width: HermesSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.appearance_preview_answer,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
