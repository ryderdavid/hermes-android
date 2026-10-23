import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/appearance_preferences.dart';
import '../theme/hermes_theme.dart';

/// Appearance → Color: a row of palette swatches, Pixel wallpaper-picker
/// style, plus the Pure black switch.
///
/// *Wallpaper* follows the device's dynamic palette and is disabled where the
/// platform offers none (Android 11 and older). Selecting a swatch applies at
/// once through [AppearancePreferences].
class AppearanceColorPicker extends StatelessWidget {
  const AppearanceColorPicker({
    required this.preferences,
    this.dynamicAvailable,
    super.key,
  });

  final AppearancePreferences preferences;

  /// Overrides the platform check; tests pass it, the app leaves it null.
  final bool? dynamicAvailable;

  @override
  Widget build(BuildContext context) {
    if (dynamicAvailable != null) {
      return _build(context, dynamicAvailable!, null);
    }
    return DynamicColorBuilder(
      builder: (light, dark) {
        final brightness = Theme.of(context).brightness;
        final wallpaper = brightness == Brightness.dark ? dark : light;
        return _build(context, wallpaper != null, wallpaper);
      },
    );
  }

  Widget _build(
    BuildContext context,
    bool wallpaperAvailable,
    ColorScheme? wallpaper,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final presetNames = [
      l10n.color_blue,
      l10n.color_green,
      l10n.color_purple,
      l10n.color_pink,
    ];
    final options = <_ColorOption>[
      _ColorOption(
        source: ColorSource.system,
        label: l10n.color_wallpaper,
        scheme:
            wallpaper ??
            (wallpaperAvailable ? theme.colorScheme : null) ??
            hermesColorScheme(brightness),
        enabled: wallpaperAvailable,
        icon: Icons.wallpaper,
      ),
      _ColorOption(
        source: ColorSource.hermesGold,
        label: l10n.color_hermes_gold,
        scheme: hermesColorScheme(brightness, seed: HermesSeeds.hermesGold),
      ),
      for (var i = 0; i < HermesSeeds.presets.length; i++)
        _ColorOption(
          source: ColorSource.seed(HermesSeeds.presets[i]),
          label: presetNames[i],
          scheme: hermesColorScheme(brightness, seed: HermesSeeds.presets[i]),
        ),
    ];

    return ValueListenableBuilder<AppearanceSettings>(
      valueListenable: appearanceSelection,
      builder: (context, appearance, _) {
        // Match on the seed, so a stored seed equal to a preset (or to the
        // gold) highlights that swatch; an unknown seed highlights none.
        final current = appearance.colorSource;
        _ColorOption? selected;
        for (final option in options) {
          final same = current.seed == null
              ? option.source.seed == null
              : option.source.seed?.toARGB32() == current.seed!.toARGB32();
          if (same) {
            selected = option;
            break;
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.color_label),
              subtitle: Text(
                selected == null
                    ? l10n.color_label
                    : selected.source == ColorSource.system
                    ? (wallpaperAvailable
                          ? l10n.color_wallpaper_description
                          : l10n.color_wallpaper_unavailable)
                    : selected.label,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                HermesSpacing.lg,
                0,
                HermesSpacing.lg,
                HermesSpacing.lg,
              ),
              child: Row(
                children: [
                  for (final option in options)
                    Padding(
                      padding: const EdgeInsets.only(right: HermesSpacing.md),
                      child: _Swatch(
                        option: option,
                        selected: option == selected,
                        onTap: option.enabled
                            ? () => preferences.setColorSource(option.source)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              key: const Key('appearance-pure-black'),
              secondary: const Icon(Icons.contrast),
              title: Text(l10n.pure_black),
              subtitle: Text(l10n.pure_black_description),
              value: appearance.pureBlack,
              onChanged: preferences.setPureBlack,
            ),
          ],
        );
      },
    );
  }
}

@immutable
class _ColorOption {
  const _ColorOption({
    required this.source,
    required this.label,
    required this.scheme,
    this.enabled = true,
    this.icon,
  });

  final ColorSource source;
  final String label;
  final ColorScheme scheme;
  final bool enabled;
  final IconData? icon;

  @override
  bool operator ==(Object other) =>
      other is _ColorOption && other.source == source;

  @override
  int get hashCode => source.hashCode;
}

/// A 56dp palette disc: primary on top, secondary and tertiary below, with a
/// check and ring when selected.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ColorOption option;
  final bool selected;
  final VoidCallback? onTap;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = option.scheme;
    final disabled = onTap == null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: option.label,
      excludeSemantics: true,
      child: Tooltip(
        message: option.label,
        child: Opacity(
          opacity: disabled ? 0.38 : 1,
          child: InkResponse(
            key: ValueKey('color-swatch-${option.source.storageValue}'),
            onTap: onTap,
            radius: size / 2 + 4,
            child: Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: CustomPaint(
                painter: _PalettePainter(
                  top: scheme.primary,
                  bottomStart: scheme.secondaryContainer,
                  bottomEnd: scheme.tertiaryContainer,
                ),
                child: Center(
                  child: selected
                      ? Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: scheme.onPrimaryContainer,
                          ),
                        )
                      : (option.icon == null
                            ? null
                            : Icon(
                                option.icon,
                                size: 18,
                                color: scheme.onPrimary,
                              )),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PalettePainter extends CustomPainter {
  const _PalettePainter({
    required this.top,
    required this.bottomStart,
    required this.bottomEnd,
  });

  final Color top;
  final Color bottomStart;
  final Color bottomEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..isAntiAlias = true;
    canvas.drawArc(rect, math.pi, math.pi, true, paint..color = top);
    canvas.drawArc(
      rect,
      math.pi / 2,
      math.pi / 2,
      true,
      paint..color = bottomStart,
    );
    canvas.drawArc(rect, 0, math.pi / 2, true, paint..color = bottomEnd);
  }

  @override
  bool shouldRepaint(_PalettePainter old) =>
      old.top != top ||
      old.bottomStart != bottomStart ||
      old.bottomEnd != bottomEnd;
}
