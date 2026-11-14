import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A Material 3 Expressive shape from the shape library, drawn as a polar
/// curve `r(θ) = (1 + amplitude · cos(lobes · θ)) / (1 + amplitude)`.
///
/// Flutter 3.44 ships no shape library (design D1, D2), so the few shapes the
/// app uses are approximated this way: close enough to read as the M3E shapes
/// at avatar and indicator sizes, and cheap to morph between.
@immutable
class ExpressiveShape {
  const ExpressiveShape(
    this.name,
    this.lobes,
    this.amplitude, [
    this.rotation = 0,
  ]);

  final String name;
  final int lobes;
  final double amplitude;

  /// Turn applied to every outline, in radians, so shapes like the 4-sided
  /// cookie sit flat rather than on a point.
  final double rotation;

  static const cookie = ExpressiveShape('cookie', 9, 0.07);
  static const clover = ExpressiveShape('clover', 4, 0.22);
  static const sunny = ExpressiveShape('sunny', 8, 0.05);
  static const burst = ExpressiveShape('burst', 12, 0.08);
  static const flower = ExpressiveShape('flower', 6, 0.14);
  static const soft = ExpressiveShape('soft', 4, 0.06);
  static const cookie6 = ExpressiveShape('cookie6', 6, 0.09);
  static const cookie4 = ExpressiveShape('cookie4', 4, 0.13, math.pi / 4);
  static const clover8 = ExpressiveShape('clover8', 8, 0.15);
  static const pentagon = ExpressiveShape('pentagon', 5, 0.08, -math.pi / 2);

  /// Shapes used for project and connection marks, in assignment order.
  static const marks = [cookie, flower, clover, burst, sunny, soft];

  /// Shapes a chat's topic icon may sit in, picked by a hash of its id.
  static const chatMarks = [
    cookie,
    cookie6,
    cookie4,
    clover,
    clover8,
    sunny,
    burst,
    flower,
    pentagon,
  ];

  /// The sequence the M3E loading indicator — and any busy [ShapeMark] —
  /// morphs through, in order.
  static const morphSequence = [cookie, clover, burst, flower, sunny];

  /// The outline inside [rect], starting at angle 0 and turned by [rotation]
  /// radians.
  Path path(Rect rect, {double rotation = 0}) {
    final center = rect.center;
    final radius = rect.shortestSide / 2;
    final path = Path();
    const steps = 180;
    for (var i = 0; i <= steps; i++) {
      final a = i * 2 * math.pi / steps;
      final r =
          radius * (1 + amplitude * math.cos(lobes * a)) / (1 + amplitude);
      final turn = a + rotation + this.rotation;
      final p = center + Offset(math.cos(turn), math.sin(turn)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool operator ==(Object other) =>
      other is ExpressiveShape &&
      other.lobes == lobes &&
      other.amplitude == amplitude &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(lobes, amplitude, rotation);

  @override
  String toString() => 'ExpressiveShape.$name';
}

/// Paints the Material 3 Expressive loading morph: the outline interpolated
/// between consecutive [ExpressiveShape.morphSequence] entries at [progress]
/// (0..1 over one full cycle), rotating twice per cycle. Shared by
/// [ExpressiveLoadingIndicator] and busy [ShapeMark]s.
class ExpressiveMorphPainter extends CustomPainter {
  ExpressiveMorphPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const shapes = ExpressiveShape.morphSequence;
    final scaled = progress * shapes.length;
    final index = scaled.floor() % shapes.length;
    final from = shapes[index];
    final to = shapes[(index + 1) % shapes.length];
    // Hold each shape briefly, then morph with an ease that overshoots a
    // little, the way the spring-driven indicator settles.
    final local = scaled - scaled.floor();
    final t = Curves.easeInOutBack.transform(
      ((local - 0.35) / 0.65).clamp(0.0, 1.0),
    );
    final rotation = progress * 2 * math.pi * 2;
    final scale = 1 - 0.08 * math.sin(local * math.pi);

    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 * scale;
    final path = Path();
    const steps = 144;
    for (var i = 0; i <= steps; i++) {
      final a = i * 2 * math.pi / steps;
      double r(ExpressiveShape s) =>
          (1 + s.amplitude * math.cos(s.lobes * a)) / (1 + s.amplitude);
      final rr = radius * (r(from) * (1 - t) + r(to) * t);
      final p =
          center + Offset(math.cos(a + rotation), math.sin(a + rotation)) * rr;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(ExpressiveMorphPainter old) =>
      old.progress != progress || old.color != color;
}

/// An [ExpressiveShape] as a [ShapeBorder], for `Material`, `ShapeDecoration`
/// and clipping.
class ExpressiveShapeBorder extends OutlinedBorder {
  const ExpressiveShapeBorder(this.shape, {super.side});

  final ExpressiveShape shape;

  @override
  ExpressiveShapeBorder copyWith({BorderSide? side}) =>
      ExpressiveShapeBorder(shape, side: side ?? this.side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      shape.path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      shape.path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(shape.path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) =>
      ExpressiveShapeBorder(shape, side: side.scale(t));
}

/// A container role pairing used to fill a [ShapeMark].
enum MarkTone { primary, secondary, tertiary }

/// The shape and tone a project, connection or chat group is drawn with.
@immutable
class MarkStyle {
  const MarkStyle(this.shape, this.tone);

  final ExpressiveShape shape;
  final MarkTone tone;

  /// A stable style for [key] (a project id or name), so one project looks
  /// the same on Home, in Chats and in the chat app bar.
  factory MarkStyle.forKey(String key) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final shape = ExpressiveShape.marks[hash % ExpressiveShape.marks.length];
    final tone = MarkTone.values[(hash ~/ 7) % MarkTone.values.length];
    return MarkStyle(shape, tone);
  }

  /// Chats with no project share this mark.
  static const unassigned = MarkStyle(ExpressiveShape.soft, MarkTone.secondary);

  @override
  bool operator ==(Object other) =>
      other is MarkStyle && other.shape == shape && other.tone == tone;

  @override
  int get hashCode => Object.hash(shape, tone);

  (Color, Color) colors(ColorScheme scheme) => switch (tone) {
    MarkTone.primary => (scheme.primaryContainer, scheme.onPrimaryContainer),
    MarkTone.secondary => (
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
    ),
    MarkTone.tertiary => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
  };
}

/// An expressive shape filled with a container role, holding an [icon] or
/// the first letter of [label].
class ShapeMark extends StatelessWidget {
  const ShapeMark({
    required this.style,
    this.label,
    this.icon,
    this.size = 44,
    this.iconScale = 0.45,
    this.busy = false,
    super.key,
  });

  final MarkStyle style;
  final String? label;
  final IconData? icon;
  final double size;

  /// The icon's size as a fraction of [size].
  final double iconScale;

  /// While true, the background morphs and spins through
  /// [ExpressiveShape.morphSequence] (the M3E loading animation); the glyph
  /// on top stays still.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = style.colors(Theme.of(context).colorScheme);
    final text = (label ?? '').trim();
    final glyph = icon != null
        ? Icon(icon, size: size * iconScale, color: ink)
        : Text(
            text.isEmpty ? '' : text.characters.first.toUpperCase(),
            style: TextStyle(
              color: ink,
              fontSize: size * 0.38,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          );
    return ExcludeSemantics(
      child: busy
          ? _MorphingShapeMark(
              fill: fill,
              size: size,
              child: Center(child: glyph),
            )
          : SizedBox.square(
              dimension: size,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: fill,
                  shape: ExpressiveShapeBorder(style.shape),
                ),
                child: Center(child: glyph),
              ),
            ),
    );
  }
}

/// A [ShapeMark] background running the M3E morph, with a still [child] on
/// top. Kept separate from [ShapeMark] so the idle path stays stateless and
/// pixel-identical.
class _MorphingShapeMark extends StatefulWidget {
  const _MorphingShapeMark({
    required this.fill,
    required this.size,
    required this.child,
  });

  final Color fill;
  final double size;
  final Widget child;

  @override
  State<_MorphingShapeMark> createState() => _MorphingShapeMarkState();
}

class _MorphingShapeMarkState extends State<_MorphingShapeMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: 650 * ExpressiveShape.morphSequence.length,
    ),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: ExpressiveMorphPainter(
                    progress: _controller.value,
                    color: widget.fill,
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
