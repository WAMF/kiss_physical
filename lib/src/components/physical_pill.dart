import 'package:flutter/material.dart';
import 'package:kiss_physical/src/components/physical_defaults.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

/// A physical pill with fully rounded ends that clips [child] to its
/// outline. Suited to short full-width rows.
class PhysicalPill extends StatelessWidget {
  /// Creates a pill around [child].
  const PhysicalPill({
    required this.child,
    super.key,
    this.color,
    this.material = PhysicalMaterial.gloss,
    this.height,
  });

  /// What the pill holds, clipped to its rounded outline.
  final Widget child;

  /// The colour of the pill. Defaults to the secondary background of the
  /// nearest `SemanticColors`, or the surface colour of the theme.
  final Color? color;

  /// How the pill is shaped and how it catches the light.
  final PhysicalMaterial material;

  /// A fixed height, or null to take the height of [child].
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: PhysicalSurface(
        color: color ?? PhysicalDefaults.surfaceColor(context),
        material: material,
        borderRadius: PhysicalSurface.stadium,
        clipBehavior: Clip.hardEdge,
        child: child,
      ),
    );
  }
}
