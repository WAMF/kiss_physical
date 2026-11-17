import 'package:flutter/material.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

/// A physical pill with fully rounded ends that clips [content] to its
/// outline. Suited to short full-width rows.
class PhysicalPill extends StatelessWidget {
  /// Creates a pill around [content].
  const PhysicalPill({
    required this.content,
    super.key,
    this.backgroundColor,
    this.material = PhysicalMaterial.gloss,
    this.height,
  });

  /// What the pill holds, clipped to its rounded outline.
  final Widget content;

  /// The colour of the pill. Defaults to the surface colour of the theme.
  final Color? backgroundColor;

  /// How the pill is shaped and how it catches the light.
  final PhysicalMaterial material;

  /// A fixed height, or null to take the height of [content].
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: PhysicalSurface(
        color: backgroundColor ?? theme.colorScheme.surface,
        material: material,
        borderRadius: PhysicalSurface.stadium,
        clipBehavior: Clip.hardEdge,
        child: content,
      ),
    );
  }
}
