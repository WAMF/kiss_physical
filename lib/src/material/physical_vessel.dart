import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A physical body made of glass, empty or holding a liquid.
///
/// Glass is what a body is, like its texture, and not something happening
/// to it: it takes the place of the body's own colour and texture, and
/// effects such as fire and rain then act on it as on any other body.
///
/// ```dart
/// PhysicalMaterial.gloss.withVessel(const PhysicalVessel.liquid())
/// ```
@immutable
class PhysicalVessel {
  /// Glass tinted [color], from clear at an [opacity] of 0 to nearly solid
  /// at 1. It is thickest, and shows most of its colour, where its edge
  /// turns away.
  const PhysicalVessel.glass({
    this.color = _Glass.clear,
    this.opacity = _Glass.opacity,
  })  : holdsLiquid = false,
        fill = 0,
        density = 0,
        gravity = null,
        assert(opacity >= 0 && opacity <= 1, 'opacity must be in [0, 1]');

  /// A glass vessel holding a liquid in [color] up to [fill], from empty at
  /// 0 to brimming at 1. [density] is how dark the liquid gets through its
  /// depth, from water at 0 to syrup at 1.
  ///
  /// The liquid lies level against [gravity] and sloshes when gravity
  /// turns, on a spring and with no fluid simulated.
  const PhysicalVessel.liquid({
    this.color = _Glass.liquid,
    this.fill = _Glass.fill,
    this.density = _Glass.density,
    this.gravity,
  })  : holdsLiquid = true,
        opacity = _Glass.vesselOpacity,
        assert(fill >= 0 && fill <= 1, 'fill must be in [0, 1]'),
        assert(density >= 0 && density <= 1, 'density must be in [0, 1]');

  /// The tint of empty glass, or the colour of the liquid it holds.
  final Color color;

  /// How solid the glass is, from 0 to 1.
  final double opacity;

  /// Whether there is liquid in the glass.
  final bool holdsLiquid;

  /// How full the vessel is, from 0 to 1.
  final double fill;

  /// How dark the liquid gets through its depth, from 0 to 1.
  final double density;

  /// Which way is down for the liquid, within the plane of the screen.
  /// Left null, it follows the real world's gravity as the device is
  /// tilted, taken from the nearest `PhysicalLight`.
  final Offset? gravity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhysicalVessel &&
          other.color == color &&
          other.opacity == opacity &&
          other.holdsLiquid == holdsLiquid &&
          other.fill == fill &&
          other.density == density &&
          other.gravity == gravity;

  @override
  int get hashCode =>
      Object.hash(color, opacity, holdsLiquid, fill, density, gravity);
}

class _Glass {
  static const clear = Color(0xFFDDEFF2);
  static const liquid = Color(0xFFC8641E);
  static const opacity = 0.25;
  static const vesselOpacity = 0.18;
  static const fill = 0.6;
  static const density = 0.5;
}
