import 'package:flutter/foundation.dart';

/// What has settled on a physical body and stays there: dew.
///
/// Decals are a layer over a `PhysicalMaterial` and its `PhysicalTexture`,
/// drawn by the same shader with no images. They read the surface beneath
/// them: dew beads on smooth faces and soaks into rough ones.
///
/// What they read is a hint map the shader builds as it applies each layer
/// in turn: the shape, the texture and the wear each record where hollows
/// and shelter are, and water reads all of it. [showHints] draws that map.
///
/// Decals do not move. Things that do, such as rain, are a
/// `PhysicalEffect`.
///
/// ```dart
/// PhysicalMaterial.satin
///     .withTexture(PhysicalTexture.granite.imperfect(0.7))
///     .withDecals(const PhysicalDecals(dew: 0.4))
/// ```
@immutable
class PhysicalDecals {
  /// Creates a layer of dew, from 0 to 1.
  const PhysicalDecals({
    this.dew = 0,
    this.showHints = false,
  }) : assert(dew >= 0 && dew <= 1, 'dew must be in [0, 1]');

  /// Nothing on the body.
  static const none = PhysicalDecals();

  /// How heavily still droplets have settled, from 0 to 1.
  final double dew;

  /// Draws the hint map in place of the surface, for seeing what the layers
  /// tell each other: hollows such as cracks, pits and grooves in red and
  /// water in blue, over grey where the surface is sheltered.
  final bool showHints;

  /// Whether nothing has settled, so there is nothing to draw.
  bool get isEmpty => dew == 0 && !showHints;

  /// These decals with the given fields replaced.
  PhysicalDecals copyWith({double? dew, bool? showHints}) {
    return PhysicalDecals(
      dew: dew ?? this.dew,
      showHints: showHints ?? this.showHints,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PhysicalDecals &&
            other.dew == dew &&
            other.showHints == showHints;
  }

  @override
  int get hashCode => Object.hash(dew, showHints);
}
