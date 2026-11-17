import 'package:flutter/material.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_pressable.dart';

/// A Material button drawn as a glossy physical pill of [color], keeping the
/// focus, semantics and sizing of an [ElevatedButton].
class PhysicalPillButton extends StatelessWidget {
  /// Creates a pill button around [child].
  const PhysicalPillButton({
    required this.color,
    required this.foregroundColor,
    required this.onPressed,
    required this.child,
    this.material = PhysicalMaterial.gloss,
    this.minimumSize,
    super.key,
  });

  /// The colour of the pill.
  final Color color;

  /// The colour of text and icons on the pill.
  final Color foregroundColor;

  /// Called on tap. The button is frosted over and inert when null.
  final VoidCallback? onPressed;

  /// The label of the button.
  final Widget child;

  /// How the pill is shaped and how it catches the light.
  final PhysicalMaterial material;

  /// The smallest the button may be, or null for the size the theme gives.
  final Size? minimumSize;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      clipBehavior: Clip.none,
      style: physicalButtonStyle(
        color: color,
        foregroundColor: foregroundColor,
        material: material,
        minimumSize: minimumSize,
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}
