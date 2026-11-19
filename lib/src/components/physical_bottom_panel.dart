import 'package:flutter/material.dart';
import 'package:kiss_physical/src/components/physical_defaults.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

/// A physical panel docked to the bottom edge, rounded on its top corners
/// and padded for the bottom safe area.
class PhysicalBottomPanel extends StatelessWidget {
  /// Creates a bottom panel behind [child].
  const PhysicalBottomPanel({
    required this.child,
    required this.backgroundColor,
    this.isRaised = false,
    super.key,
  });

  /// What the panel holds, kept clear of the bottom safe area.
  final Widget child;

  /// The colour of the panel.
  final Color backgroundColor;

  /// Whether the panel floats above the content and casts a shadow.
  final bool isRaised;

  @override
  Widget build(BuildContext context) {
    return PhysicalSurface(
      color: backgroundColor,
      material:
          isRaised ? PhysicalMaterial.floatingPanel : PhysicalMaterial.panel,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PhysicalDefaults.cornerRadius(context)),
      ),
      clipBehavior: Clip.hardEdge,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: child,
      ),
    );
  }
}
