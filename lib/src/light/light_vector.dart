import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Unit direction from a surface towards the light, in screen axes with z
/// pointing at the viewer.
@immutable
class LightVector {
  /// Creates a direction from its three parts, which should have unit length.
  const LightVector(this.x, this.y, this.z);

  /// The light whose screen-plane part is [direction].
  ///
  /// The light is kept in front of the screen however the device is held,
  /// so surfaces are never lit from behind.
  factory LightVector.towards(Offset direction) {
    var lean = direction * _leanGain;
    final distance = lean.distance;
    if (distance > _maxLean) lean = lean * (_maxLean / distance);
    final length = math.sqrt(lean.distanceSquared + 1);
    return LightVector(lean.dx / length, lean.dy / length, 1 / length);
  }

  static const _leanGain = 1.15;
  static const _maxLean = 1.15;

  /// The part across the screen, positive towards the right.
  final double x;

  /// The part down the screen, positive towards the bottom.
  final double y;

  /// The part out of the screen, towards the viewer.
  final double z;
}
