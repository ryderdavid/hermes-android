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
    super.key,
  });

  final MarkStyle style;
  final String? label;
  final IconData? icon;
  final double size;

  /// The icon's size as a fraction of [size].
  final double iconScale;

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
      child: SizedBox.square(
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
