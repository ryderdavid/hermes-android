import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Material 3 Expressive motion: springs instead of fixed-duration easing.
///
/// Spatial springs move position, size and shape and may overshoot; effects
/// springs change colour and opacity and never overshoot. Values follow the
/// Expressive motion scheme (damping ratio, stiffness).
abstract final class HermesSprings {
  static const spatialFast = SpringDescription(
    mass: 1,
    stiffness: 800,
    damping: _d * 0.6 * 28.284271247461902,
  );
  static const spatialDefault = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: _d * 0.8 * 19.493588689617926,
  );
  static const spatialSlow = SpringDescription(
    mass: 1,
    stiffness: 200,
    damping: _d * 0.8 * 14.142135623730951,
  );
  static const effectsFast = SpringDescription(
    mass: 1,
    stiffness: 3800,
    damping: _d * 1.0 * 61.644140029689765,
  );
  static const effectsDefault = SpringDescription(
    mass: 1,
    stiffness: 1600,
    damping: _d * 1.0 * 40,
  );
  static const effectsSlow = SpringDescription(
    mass: 1,
    stiffness: 800,
    damping: _d * 1.0 * 28.284271247461902,
  );

  // damping = ratio · 2 · √(stiffness · mass); √stiffness is precomputed above
  // so the descriptions stay const.
  static const double _d = 2;

  /// Shape changes on buttons (Send → Stop, selection in a button group).
  static const Curve shape = SpringCurve(spatialFast);
  static const Duration shapeDuration = Duration(milliseconds: 350);

  /// Colour and emphasis changes.
  static const Curve effect = SpringCurve(effectsDefault);
  static const Duration effectDuration = Duration(milliseconds: 200);
}

/// A [Curve] that follows a unit spring from 0 to 1, for implicit animations.
///
/// The curve's time is normalised: `transform(1)` is pinned to 1 so the
/// animation always lands, and the duration given to the implicit animation
/// should be long enough for the spring to settle.
class SpringCurve extends Curve {
  const SpringCurve(this.spring, {this.settleSeconds = 0.5});

  final SpringDescription spring;

  /// Real time the curve's 0..1 spans.
  final double settleSeconds;

  @override
  double transformInternal(double t) {
    final simulation = SpringSimulation(spring, 0, 1, 0);
    return simulation.x(t * settleSeconds);
  }
}
