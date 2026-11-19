import 'package:flutter/material.dart';
import 'package:kiss_physical/src/components/physical_defaults.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

/// A rounded physical slab that clips [child] to its outline.
class PhysicalCard extends StatelessWidget {
  /// Creates a card around [child].
  const PhysicalCard({
    required this.child,
    super.key,
    this.color,
    this.borderRadius,
    this.material = PhysicalMaterial.satin,
    this.height,
    this.width,
  });

  /// What the card holds, clipped to its rounded outline.
  final Widget child;

  /// The colour of the slab. Defaults to the secondary background of the
  /// nearest `SemanticColors`, or the surface colour of the theme.
  final Color? color;

  /// Defaults to the large corner radius of the nearest `Layout`, or of the
  /// standard layout, on every corner.
  final BorderRadius? borderRadius;

  /// How the slab is shaped and how it catches the light.
  final PhysicalMaterial material;

  /// A fixed height, or null to take the height of [child].
  final double? height;

  /// A fixed width, or null to take the width of [child].
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: PhysicalSurface(
        color: color ?? PhysicalDefaults.surfaceColor(context),
        material: material,
        borderRadius: borderRadius ??
            BorderRadius.circular(PhysicalDefaults.cornerRadius(context)),
        clipBehavior: Clip.hardEdge,
        child: child,
      ),
    );
  }
}
