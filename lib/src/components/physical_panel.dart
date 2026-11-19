import 'package:flutter/material.dart';
import 'package:kiss_physical/src/components/physical_defaults.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

/// A physical panel in the secondary background colour with the large
/// corner radius of the layout.
class PhysicalPanel extends StatelessWidget {
  /// Creates a panel behind [child].
  const PhysicalPanel({
    required this.child,
    super.key,
    this.backgroundColor,
    this.borderRadius,
    this.isRaised = false,
  });

  /// What the panel holds.
  final Widget child;

  /// The colour of the panel. Defaults to the secondary background of the
  /// nearest `SemanticColors`, or the surface colour of the theme.
  final Color? backgroundColor;

  /// Defaults to the large corner radius of the nearest `Layout`, or of the
  /// standard layout, on every corner.
  final BorderRadius? borderRadius;

  /// Whether the panel floats above its parent and casts a shadow.
  final bool isRaised;

  @override
  Widget build(BuildContext context) {
    return PhysicalSurface(
      color: backgroundColor ?? PhysicalDefaults.surfaceColor(context),
      material:
          isRaised ? PhysicalMaterial.floatingPanel : PhysicalMaterial.panel,
      borderRadius: borderRadius ??
          BorderRadius.circular(PhysicalDefaults.cornerRadius(context)),
      child: child,
    );
  }
}
