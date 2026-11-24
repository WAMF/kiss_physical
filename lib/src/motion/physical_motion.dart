import 'dart:math' as math;

import 'package:flutter/physics.dart';

/// The arithmetic of things that are thrown, dragged past an edge and left
/// to settle, shared by every gesture in the kit.
abstract final class PhysicalMotion {
  /// How far something let go at [velocity], in logical pixels a second,
  /// coasts before friction stops it.
  ///
  /// [glide] is the share of its speed it keeps each millisecond.
  static double throwDistance(double velocity, {double glide = defaultGlide}) {
    assert(glide > 0 && glide < 1, 'glide must be between 0 and 1');
    return velocity / _Throw.millisecondsPerSecond * glide / (1 - glide);
  }

  /// Where something at [position] let go at [velocity] comes to rest.
  static double restingPlace(
    double position,
    double velocity, {
    double glide = defaultGlide,
  }) {
    return position + throwDistance(velocity, glide: glide);
  }

  /// The one of [stops] that something at [position] let go at [velocity]
  /// should settle on: the nearest to where the throw would carry it.
  static double stopFor(
    double position,
    double velocity,
    Iterable<double> stops, {
    double glide = defaultGlide,
  }) {
    assert(stops.isNotEmpty, 'there must be a stop to settle on');
    final landing = restingPlace(position, velocity, glide: glide);
    return stops.reduce(
      (nearest, stop) =>
          (stop - landing).abs() < (nearest - landing).abs() ? stop : nearest,
    );
  }

  /// How far something shows as moved when dragged [overshoot] past an edge
  /// it cannot leave, so it gives a little and then holds.
  ///
  /// The result starts as [give] of the drag and never passes [extent],
  /// however far the drag goes.
  static double resisted(
    double overshoot, {
    required double extent,
    double give = defaultGive,
  }) {
    assert(extent > 0, 'extent must be positive');
    final distance = overshoot.abs();
    final shown = distance * extent * give / (extent + give * distance);
    return shown * overshoot.sign;
  }

  /// [value] held to the range from [lowest] to [highest], giving a little
  /// past either end in the way of [resisted].
  static double heldWithin(
    double value, {
    required double lowest,
    required double highest,
    double give = defaultGive,
  }) {
    final extent = math.max(highest - lowest, _Throw.smallestExtent);
    if (value < lowest) {
      return lowest + resisted(value - lowest, extent: extent, give: give);
    }
    if (value > highest) {
      return highest + resisted(value - highest, extent: extent, give: give);
    }
    return value;
  }

  /// The spring that carries a sheet, a row or a page to where it settles:
  /// quick, and with only the slightest give when it arrives.
  static final carry = SpringDescription.withDampingRatio(
    mass: _Carry.mass,
    stiffness: _Carry.stiffness,
    ratio: _Carry.ratio,
  );

  /// How close to where it is going, and how nearly still, something
  /// measured in logical pixels must be to count as settled.
  static const settledInPixels = Tolerance(distance: 0.5, velocity: 5);

  /// The share of its speed a thrown body keeps each millisecond.
  static const defaultGlide = 0.998;

  /// How much of a drag past an edge shows at first.
  static const defaultGive = 0.55;
}

class _Throw {
  static const millisecondsPerSecond = 1000;
  static const smallestExtent = 1.0;
}

class _Carry {
  static const mass = 1.0;
  static const stiffness = 320.0;
  static const ratio = 0.86;
}
