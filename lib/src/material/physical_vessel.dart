import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A physical body made of glass.
///
/// Glass is what a body is, like its texture, and not something happening
/// to it: it takes the place of the body's own colour and texture, and
/// effects such as fire and rain then act on it as on any other body.
///
/// ```dart
/// PhysicalMaterial.gloss.withVessel(const PhysicalVessel.glass())
/// ```
@immutable
class PhysicalVessel {
  /// Glass tinted [color], from clear at an [opacity] of 0 to nearly solid
  /// at 1. It is thickest, and shows most of its colour, where its edge
  /// turns away.
  const PhysicalVessel.glass({
    this.color = _Glass.clear,
    this.opacity = _Glass.opacity,
  }) : assert(opacity >= 0 && opacity <= 1, 'opacity must be in [0, 1]');

  /// The tint of the glass.
  final Color color;

  /// How solid the glass is, from 0 to 1.
  final double opacity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhysicalVessel &&
          other.color == color &&
          other.opacity == opacity;

  @override
  int get hashCode => Object.hash(color, opacity);
}

class _Glass {
  static const clear = Color(0xFFDDEFF2);
  static const opacity = 0.25;
}
