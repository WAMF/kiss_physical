import 'package:flutter/material.dart';
import 'package:kiss_physical/src/components/physical_defaults.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

/// A physical body that clips [child] to its outline: a rounded slab, a
/// pill or a disc.
class PhysicalCard extends StatelessWidget {
  /// Creates a rounded slab around [child].
  const PhysicalCard({
    required this.child,
    this.color,
    this.borderRadius,
    this.material = PhysicalMaterial.satin,
    this.width,
    this.height,
    super.key,
  });

  /// Creates a glossy pill with fully rounded ends around [child]. Suited
  /// to short full-width rows.
  const PhysicalCard.pill({
    required this.child,
    this.color,
    this.material = PhysicalMaterial.gloss,
    this.width,
    this.height,
    super.key,
  }) : borderRadius = PhysicalSurface.stadium;

  /// Creates a domed disc around [child], [diameter] across when one is
  /// given.
  const PhysicalCard.disc({
    required this.child,
    this.color,
    this.material = PhysicalMaterial.bead,
    double? diameter,
    super.key,
  })  : borderRadius = PhysicalSurface.stadium,
        width = diameter,
        height = diameter;

  /// What the card holds, clipped to its outline.
  final Widget child;

  /// The colour of the card. Defaults to the secondary background of the
  /// nearest `SemanticColors`, or the surface colour of the theme.
  final Color? color;

  /// The corner radii of the card. Defaults to the large corner radius of
  /// the nearest `Layout`, or of the standard layout, on every corner.
  final BorderRadius? borderRadius;

  /// How the card is shaped and how it catches the light. A texture on it
  /// is tinted to the card's colour.
  final PhysicalMaterial material;

  /// A fixed width, or null to take the width of [child].
  final double? width;

  /// A fixed height, or null to take the height of [child].
  final double? height;

  @override
  Widget build(BuildContext context) {
    final shown = color ?? PhysicalDefaults.surfaceColor(context);
    return SizedBox(
      width: width,
      height: height,
      child: PhysicalSurface(
        color: shown,
        material: material.tintedTo(shown),
        borderRadius: borderRadius ??
            BorderRadius.circular(PhysicalDefaults.cornerRadius(context)),
        clipBehavior: Clip.hardEdge,
        child: child,
      ),
    );
  }
}
