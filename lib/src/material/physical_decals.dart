import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Things that have grown or settled on a physical body and stay there:
/// moss, grass and flowers, and dew.
///
/// Decals are a layer over a `PhysicalMaterial` and its `PhysicalTexture`,
/// drawn by the same shader with no images. They read the surface beneath
/// them: growth starts in cracks, pits and along edges and spreads out from
/// there, and dew beads on smooth faces and soaks into rough ones.
///
/// What they read is a hint map the shader builds as it applies each layer
/// in turn: the shape, the texture and the wear each record where hollows
/// and shelter are, growth records what it covers, and water reads all of
/// it. [showHints] draws that map.
///
/// Decals do not move. Growth is worked out once and kept, so it costs
/// nothing from frame to frame. Things that do move, such as rain, are a
/// `PhysicalEffect`.
///
/// ```dart
/// PhysicalMaterial.satin
///     .withTexture(PhysicalTexture.granite.imperfect(0.7))
///     .withDecals(const PhysicalDecals(moss: 0.5, dew: 0.4))
/// ```
@immutable
class PhysicalDecals {
  /// Creates a layer of growth and dew; every amount runs from 0 to 1.
  const PhysicalDecals({
    this.moss = 0,
    this.grass = 0,
    this.flowers = 0,
    this.flowerColor = defaultFlowerColor,
    this.dew = 0,
    this.gravity,
    this.showHints = false,
  })  : assert(moss >= 0 && moss <= 1, 'moss must be in [0, 1]'),
        assert(grass >= 0 && grass <= 1, 'grass must be in [0, 1]'),
        assert(flowers >= 0 && flowers <= 1, 'flowers must be in [0, 1]'),
        assert(dew >= 0 && dew <= 1, 'dew must be in [0, 1]');

  /// A bare surface.
  static const none = PhysicalDecals();

  /// A pale pink, as of small wild flowers.
  static const defaultFlowerColor = Color(0xFFE9B6D8);

  /// Straight down the screen at full strength, as on a wall.
  static const defaultGravity = Offset(0, 1);

  /// How far moss has spread, from 0 (none) to 1 (overgrown).
  final double moss;

  /// How much grass has come up, from 0 to 1. Blades grow against
  /// [gravity].
  final double grass;

  /// How many flowers there are and how far they have opened, from 0 to 1.
  final double flowers;

  /// The colour of the petals.
  final Color flowerColor;

  /// How heavily still droplets have settled, from 0 to 1.
  final double dew;

  /// Which way was down, within the plane of the screen, as the growth came
  /// up: grass stands against it. Left null, it grew as on a wall, with
  /// down at the bottom of the screen.
  final Offset? gravity;

  /// Draws the hint map in place of the surface, for seeing what the layers
  /// tell each other: hollows such as cracks, pits and grooves in red,
  /// growth in green and water in blue, over grey where the surface is
  /// sheltered.
  final bool showHints;

  /// Whether nothing has settled or grown, so there is nothing to draw.
  bool get isEmpty =>
      moss == 0 && grass == 0 && flowers == 0 && dew == 0 && !showHints;

  /// These decals with the given values replaced.
  PhysicalDecals copyWith({
    double? moss,
    double? grass,
    double? flowers,
    Color? flowerColor,
    double? dew,
    Offset? gravity,
    bool? showHints,
  }) {
    return PhysicalDecals(
      moss: moss ?? this.moss,
      grass: grass ?? this.grass,
      flowers: flowers ?? this.flowers,
      flowerColor: flowerColor ?? this.flowerColor,
      dew: dew ?? this.dew,
      gravity: gravity ?? this.gravity,
      showHints: showHints ?? this.showHints,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhysicalDecals &&
          other.moss == moss &&
          other.grass == grass &&
          other.flowers == flowers &&
          other.flowerColor == flowerColor &&
          other.dew == dew &&
          other.gravity == gravity &&
          other.showHints == showHints;

  @override
  int get hashCode => Object.hash(
        moss,
        grass,
        flowers,
        flowerColor,
        dew,
        gravity,
        showHints,
      );
}
