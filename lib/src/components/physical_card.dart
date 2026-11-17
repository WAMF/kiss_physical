import 'package:flutter/material.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

/// A rounded physical slab that clips [content] to its outline.
class PhysicalCard extends StatelessWidget {
  /// Creates a card around [content].
  const PhysicalCard({
    required this.content,
    super.key,
    this.backgroundColor,
    this.borderRadius,
    this.material = PhysicalMaterial.satin,
    this.height,
    this.width,
  });

  /// What the card holds, clipped to its rounded outline.
  final Widget content;

  /// The colour of the slab. Defaults to the surface colour of the theme.
  final Color? backgroundColor;

  /// Defaults to the large corner radius of the layout on every corner.
  final BorderRadius? borderRadius;

  /// How the slab is shaped and how it catches the light.
  final PhysicalMaterial material;

  /// A fixed height, or null to take the height of [content].
  final double? height;

  /// A fixed width, or null to take the width of [content].
  final double? width;

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      width: width,
      child: PhysicalSurface(
        color: backgroundColor ?? theme.colorScheme.surface,
        material: material,
        borderRadius:
            borderRadius ?? BorderRadius.circular(layout.cornerRadii.large),
        clipBehavior: Clip.hardEdge,
        child: content,
      ),
    );
  }
}
