import 'package:flutter/material.dart';
import 'package:kiss_physical/src/components/physical_defaults.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

/// A domed physical disc that clips [child] to its outline.
class PhysicalDisc extends StatelessWidget {
  /// Creates a disc around [child].
  const PhysicalDisc({
    required this.child,
    super.key,
    this.color,
  });

  /// What the disc holds, clipped to its round outline.
  final Widget child;

  /// The colour of the disc. Defaults to the secondary background of the
  /// nearest `SemanticColors`, or the surface colour of the theme.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return PhysicalSurface(
      color: color ?? PhysicalDefaults.surfaceColor(context),
      material: PhysicalMaterial.bead,
      borderRadius: PhysicalSurface.stadium,
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}
