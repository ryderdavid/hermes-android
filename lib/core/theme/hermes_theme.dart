/// The Hermes Android design system.
///
/// One typed token layer that every screen consumes, so spacing, radius,
/// motion, semantic status colors, and the typography ramp are decided once
/// instead of per screen. See `docs/ANDROID_DAILY_DRIVER_ROADMAP.md`
/// ("Interface overhaul") for the product rationale.
library;

import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Seed colors for schemes that are not taken from the device wallpaper.
abstract final class HermesSeeds {
  /// Used when the device offers no dynamic palette (Android 11 and older,
  /// some OEM builds) and the user has not picked a color.
  static const Color fallback = Color(0xFF4285F4);

  /// The upstream Hermes brand gold, offered as a user-selectable seed.
  static const Color hermesGold = Color(0xFFD4AF37);

  /// Preset seeds offered in Settings → Appearance → Color, in display order.
  static const List<Color> presets = [
    Color(0xFF4285F4), // Blue
    Color(0xFF34A853), // Green
    Color(0xFF7E57C2), // Purple
    Color(0xFFE91E63), // Pink
  ];
}

/// The app color scheme for [brightness].
///
/// An explicit [seed] wins. Otherwise the device's [dynamicScheme] is used
/// (harmonized so its error role sits with the wallpaper primary), and
/// without one a tonal-spot scheme is generated from [HermesSeeds.fallback].
///
/// [pureBlack] turns a dark scheme's background black while leaving the
/// container roles tonal, so cards and fields stay distinguishable.
ColorScheme hermesColorScheme(
  Brightness brightness, {
  ColorScheme? dynamicScheme,
  Color? seed,
  bool pureBlack = false,
}) {
  final scheme = seed == null && dynamicScheme != null
      ? dynamicScheme.harmonized()
      : ColorScheme.fromSeed(
          seedColor: seed ?? HermesSeeds.fallback,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
        );
  if (!pureBlack || brightness != Brightness.dark) return scheme;
  const black = Color(0xFF000000);
  return scheme.copyWith(
    surface: black,
    surfaceDim: black,
    surfaceContainerLowest: black,
  );
}

/// The 4dp spacing grid shared by every Hermes surface.
abstract final class HermesSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii, growing from small controls to full sheets.
abstract final class HermesRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Motion budget. Animations exist to explain a change, never to decorate.
abstract final class HermesMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration emphasized = Duration(milliseconds: 320);

  static const Curve curve = Curves.easeOutCubic;
}

/// Semantic state of a chat, task, or activity item.
enum HermesStatus {
  /// Work is actively progressing.
  running,

  /// Hermes cannot continue without the user (approval, clarify, secret).
  blocked,

  /// Work ended in an error.
  failed,

  /// Work ended successfully.
  completed,

  /// Nothing is happening.
  idle,
}

/// The Hermes typography ramp: named aliases onto the Material 3 type scale.
///
/// Every role is taken from [Typography.material2021] in the platform font
/// (Roboto on Android), so text follows the M3 scale and the system font-size
/// setting. [mono] owns code, file paths, and terminal output. The Cinzel
/// display face is reserved for the wordmark ([HermesTypography.wordmark]).
class HermesTypography {
  final TextStyle display;
  final TextStyle title;
  final TextStyle section;
  final TextStyle body;
  final TextStyle label;
  final TextStyle mono;

  const HermesTypography({
    required this.display,
    required this.title,
    required this.section,
    required this.body,
    required this.label,
    required this.mono,
  });

  /// The upstream wordmark face, for `HermesHeader` and onboarding only.
  static const String wordmarkFamily = 'Cinzel';

  /// The M3 scale in the platform font, colorless and inheriting, so a
  /// widget's text still takes its color from the surrounding theme.
  static TextTheme _m3(Brightness brightness) {
    final typography = Typography.material2021(platform: defaultTargetPlatform);
    final family =
        (brightness == Brightness.dark ? typography.white : typography.black)
            .bodyMedium
            ?.fontFamily;
    TextStyle? role(TextStyle? style) =>
        style?.copyWith(inherit: true, fontFamily: family);
    final scale = typography.englishLike;
    return TextTheme(
      headlineSmall: role(scale.headlineSmall),
      titleLarge: role(scale.titleLarge),
      titleMedium: role(scale.titleMedium),
      bodyMedium: role(scale.bodyMedium),
      labelMedium: role(scale.labelMedium),
    );
  }

  static HermesTypography ramp(Brightness brightness) {
    final text = _m3(brightness);
    return HermesTypography(
      display: text.headlineSmall!,
      title: text.titleLarge!,
      section: text.titleMedium!,
      body: text.bodyMedium!,
      label: text.labelMedium!,
      mono: text.bodyMedium!.copyWith(
        fontSize: 13,
        height: 1.4,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['monospace'],
      ),
    );
  }

  /// Colors the M3 [base] theme: primary text on [onSurface], supporting
  /// text on [muted]. Sizes and weights are left to the M3 scale.
  TextTheme applyTo(TextTheme base, Color onSurface, Color muted) {
    return base
        .apply(bodyColor: onSurface, displayColor: onSurface)
        .copyWith(
          bodySmall: base.bodySmall?.copyWith(color: muted),
          labelMedium: base.labelMedium?.copyWith(color: muted),
        );
  }
}

/// The Hermes design tokens, carried on [ThemeData.extensions].
@immutable
class HermesTokens extends ThemeExtension<HermesTokens> {
  /// The upstream Hermes brand gold. Now one of the selectable seeds; the
  /// accent follows the active color scheme's primary.
  static const Color hermesGold = HermesSeeds.hermesGold;

  final Brightness brightness;
  final Color surface;
  final Color raised;
  final Color border;
  final Color onSurface;
  final Color muted;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color running;
  final Color blocked;
  final HermesTypography typography;

  const HermesTokens({
    required this.brightness,
    required this.surface,
    required this.raised,
    required this.border,
    required this.onSurface,
    required this.muted,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.running,
    required this.blocked,
    required this.typography,
  });

  /// Status hues before harmonization, chosen per brightness so they keep
  /// AA contrast on that brightness's surfaces. Harmonizing rotates hue
  /// toward the scheme primary but keeps tone, so contrast is preserved.
  static const Map<Brightness, List<Color>> _statusBase = {
    // success, warning, running, blocked
    Brightness.dark: [
      Color(0xFF4ADE80),
      Color(0xFFFBBF24),
      Color(0xFF60A5FA),
      Color(0xFFF59E0B),
    ],
    Brightness.light: [
      Color(0xFF15803D),
      Color(0xFFB45309),
      Color(0xFF1D4ED8),
      Color(0xFF9A5B00),
    ],
  };

  /// Tokens derived from [scheme]: every surface and text role comes from
  /// the scheme, and status hues are harmonized to its primary.
  factory HermesTokens.fromScheme(ColorScheme scheme) {
    final brightness = scheme.brightness;
    final base = _statusBase[brightness]!;
    Color harmonize(Color color) => color.harmonizeWith(scheme.primary);
    return HermesTokens(
      brightness: brightness,
      surface: scheme.surface,
      raised: scheme.surfaceContainer,
      border: scheme.outlineVariant,
      onSurface: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      accent: scheme.primary,
      success: harmonize(base[0]),
      warning: harmonize(base[1]),
      danger: scheme.error,
      running: harmonize(base[2]),
      blocked: harmonize(base[3]),
      typography: HermesTypography.ramp(brightness),
    );
  }

  factory HermesTokens.dark() =>
      HermesTokens.fromScheme(hermesColorScheme(Brightness.dark));

  factory HermesTokens.light() =>
      HermesTokens.fromScheme(hermesColorScheme(Brightness.light));

  static HermesTokens forBrightness(Brightness brightness) {
    return brightness == Brightness.dark
        ? HermesTokens.dark()
        : HermesTokens.light();
  }

  /// The tokens for the closest theme, falling back to a set derived from its
  /// color scheme when a widget is mounted under a plain [ThemeData] (tests,
  /// previews, plugins).
  static HermesTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<HermesTokens>() ??
        HermesTokens.fromScheme(theme.colorScheme);
  }

  Color colorForStatus(HermesStatus status) {
    switch (status) {
      case HermesStatus.running:
        return running;
      case HermesStatus.blocked:
        return blocked;
      case HermesStatus.failed:
        return danger;
      case HermesStatus.completed:
        return success;
      case HermesStatus.idle:
        return muted;
    }
  }

  @override
  HermesTokens copyWith({
    Brightness? brightness,
    Color? surface,
    Color? raised,
    Color? border,
    Color? onSurface,
    Color? muted,
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? running,
    Color? blocked,
    HermesTypography? typography,
  }) {
    return HermesTokens(
      brightness: brightness ?? this.brightness,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      border: border ?? this.border,
      onSurface: onSurface ?? this.onSurface,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      running: running ?? this.running,
      blocked: blocked ?? this.blocked,
      typography: typography ?? this.typography,
    );
  }

  @override
  HermesTokens lerp(ThemeExtension<HermesTokens>? other, double t) {
    if (other is! HermesTokens) return this;
    return HermesTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      border: Color.lerp(border, other.border, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      running: Color.lerp(running, other.running, t)!,
      blocked: Color.lerp(blocked, other.blocked, t)!,
      typography: t < 0.5 ? typography : other.typography,
    );
  }
}

/// Transparent status and navigation bars whose icons contrast with
/// [scheme]'s surface, for drawing edge-to-edge.
SystemUiOverlayStyle hermesSystemUiStyle(ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    statusBarBrightness: scheme.brightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );
}

/// Builds the Hermes [ThemeData] for one brightness, tokens attached.
///
/// [colorScheme] is normally from [hermesColorScheme]; without one the
/// seeded fallback scheme is used. Its brightness must match [brightness].
ThemeData hermesTheme(Brightness brightness, {ColorScheme? colorScheme}) {
  final scheme = colorScheme ?? hermesColorScheme(brightness);
  assert(scheme.brightness == brightness);
  final tokens = HermesTokens.fromScheme(scheme);

  final base = ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    useMaterial3: true,
  );

  // Material 3 buttons: 40dp tall, 24dp side padding, fully rounded, inside a
  // 48dp touch target. Colors come from each button type's M3 defaults.
  const buttonMinimumSize = Size(64, 40);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 24);
  const buttonShape = StadiumBorder();

  // Filled text fields: tonal container, no resting outline, a primary
  // indicator when focused and the error role when invalid.
  const fieldRadius = BorderRadius.all(Radius.circular(HermesRadius.md));
  OutlineInputBorder fieldBorder([BorderSide side = BorderSide.none]) =>
      OutlineInputBorder(borderRadius: fieldRadius, borderSide: side);

  return base.copyWith(
    scaffoldBackgroundColor: tokens.surface,
    textTheme: tokens.typography.applyTo(
      base.textTheme,
      tokens.onSurface,
      tokens.muted,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // On scroll the bar lifts to surfaceContainer, as in Pixel apps.
      scrolledUnderElevation: 3,
      shadowColor: Colors.transparent,
      centerTitle: false,
      systemOverlayStyle: hermesSystemUiStyle(scheme),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonMinimumSize,
        padding: buttonPadding,
        shape: buttonShape,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: buttonMinimumSize,
        padding: buttonPadding,
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonMinimumSize,
        padding: buttonPadding,
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: buttonMinimumSize,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: buttonShape,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(minimumSize: buttonMinimumSize),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: fieldBorder(),
      enabledBorder: fieldBorder(),
      disabledBorder: fieldBorder(),
      focusedBorder: fieldBorder(BorderSide(color: scheme.primary, width: 2)),
      errorBorder: fieldBorder(BorderSide(color: scheme.error)),
      focusedErrorBorder: fieldBorder(
        BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: HermesRadius.card),
    ),
    listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
    switchTheme: SwitchThemeData(
      thumbIcon: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Icon(Icons.check)
            : null,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(HermesRadius.sm)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      actionTextColor: scheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    ),
    // The bar must keep every label on one line. At the 12sp label ramp the
    // longest catalogue entries overflow their destination and wrap — ja
    // アクティビティ (seven glyphs) is the first to go. 11sp with no tracking
    // fits the widest shipped labels while staying legible.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return tokens.typography.label.copyWith(
          fontSize: 11,
          letterSpacing: 0,
          height: 1.2,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        );
      }),
    ),
    // Android predictive back: routes preview the destination as the user
    // swipes. Other platforms keep their defaults.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
    extensions: <ThemeExtension<dynamic>>[tokens],
  );
}

/// WCAG 2.1 relative luminance contrast ratio between two opaque colors.
///
/// Exposed so accessibility expectations live in tests rather than in review
/// opinions: body text must clear 4.5:1 and secondary text 3:1.
double contrastRatio(Color foreground, Color background) {
  final a = _relativeLuminance(foreground);
  final b = _relativeLuminance(background);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}
