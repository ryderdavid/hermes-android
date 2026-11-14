import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shapes.dart';

/// The Material 3 Expressive loading indicator: an expressive shape that
/// rotates and morphs through the shape sequence, optionally on a container.
///
/// Use it for indeterminate waits shorter than a few seconds (a turn
/// starting, a reply streaming); use [WavyProgressIndicator] when progress
/// is known.
class ExpressiveLoadingIndicator extends StatefulWidget {
  const ExpressiveLoadingIndicator({
    this.size = 48,
    this.contained = true,
    this.color,
    this.containerColor,
    this.semanticsLabel,
    super.key,
  });

  final double size;

  /// Draws the shape on a circular container, as the M3E "contained" variant.
  final bool contained;
  final Color? color;
  final Color? containerColor;
  final String? semanticsLabel;

  static const sequence = ExpressiveShape.morphSequence;

  @override
  State<ExpressiveLoadingIndicator> createState() =>
      _ExpressiveLoadingIndicatorState();
}

class _ExpressiveLoadingIndicatorState extends State<ExpressiveLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: 650 * ExpressiveLoadingIndicator.sequence.length,
    ),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color =
        widget.color ?? (widget.contained ? scheme.primary : scheme.primary);
    final container = widget.containerColor ?? scheme.primaryContainer;
    final indicator = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: ExpressiveMorphPainter(
            progress: _controller.value,
            color: color,
          ),
        ),
      ),
    );
    return Semantics(
      label: widget.semanticsLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: widget.contained
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: container,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.size * 0.19),
                  child: indicator,
                ),
              )
            : indicator,
      ),
    );
  }
}

/// A Material 3 Expressive linear progress indicator whose filled part is a
/// wave. [value] null animates the wave along an indeterminate track.
class WavyProgressIndicator extends StatefulWidget {
  const WavyProgressIndicator({
    this.value,
    this.color,
    this.trackColor,
    this.height = 12,
    this.semanticsLabel,
    this.animate = true,
    super.key,
  });

  final double? value;

  /// Indeterminate waves travel along the track; false draws a still wave
  /// (for list rows, where many moving indicators would distract).
  final bool animate;
  final Color? color;
  final Color? trackColor;
  final double height;
  final String? semanticsLabel;

  @override
  State<WavyProgressIndicator> createState() => _WavyProgressIndicatorState();
}

class _WavyProgressIndicatorState extends State<WavyProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(WavyProgressIndicator old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.value == null && widget.animate) {
      if (!_phase.isAnimating) _phase.repeat();
    } else {
      _phase.stop();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = widget.value;
    return Semantics(
      label: widget.semanticsLabel,
      value: value == null ? null : '${(value * 100).round()}%',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _phase,
            builder: (context, _) => CustomPaint(
              painter: _WavePainter(
                // A still indeterminate wave shows a fixed stretch of wave.
                value: value ?? (widget.animate ? null : 0.6),
                phase: _phase.value,
                color: widget.color ?? scheme.primary,
                track: widget.trackColor ?? scheme.secondaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.value,
    required this.phase,
    required this.color,
    required this.track,
  });

  final double? value;
  final double phase;
  final Color color;
  final Color track;

  static const stroke = 4.0;
  static const wavelength = 24.0;
  static const gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final amplitude = (size.height - stroke) / 2 * 0.8;
    final start = stroke / 2;
    final end = size.width - stroke / 2;
    final paint = Paint()
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Indeterminate: a wave segment travelling along the track.
    final v = value;
    final double from;
    final double to;
    if (v == null) {
      final span = (end - start) * 0.4;
      final head = start + (end - start + span) * phase;
      from = (head - span).clamp(start, end);
      to = head.clamp(start, end);
    } else {
      from = start;
      to = start + (end - start) * v.clamp(0.0, 1.0);
    }

    final trackPaint = paint..color = track;
    if (from - gap > start) {
      canvas.drawLine(Offset(start, mid), Offset(from - gap, mid), trackPaint);
    }
    if (to + gap < end) {
      canvas.drawLine(Offset(to + gap, mid), Offset(end, mid), trackPaint);
    }
    if (to <= from) return;
    final wave = Path()..moveTo(from, mid);
    for (var x = from; x <= to; x += 1) {
      final y =
          mid + amplitude * math.sin((x / wavelength + phase) * 2 * math.pi);
      wave.lineTo(x, y);
    }
    canvas.drawPath(
      wave,
      Paint()
        ..color = color
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.value != value ||
      old.phase != phase ||
      old.color != color ||
      old.track != track;
}
