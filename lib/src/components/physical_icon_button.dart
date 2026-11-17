import 'package:flutter/material.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_pressable.dart';

/// A round physical button that sinks when pressed.
class PhysicalIconButton extends StatelessWidget {
  /// Creates a round button showing [icon].
  const PhysicalIconButton({
    required this.icon,
    required this.diameter,
    required this.onTap,
    super.key,
    this.backgroundColor,
  });

  /// What is shown at the centre of the button.
  final Widget icon;

  /// The width and height of the button in logical pixels.
  final double diameter;

  /// The colour of the button. Defaults to the surface colour of the theme.
  final Color? backgroundColor;

  /// Called on tap. The button is inert when null.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: diameter,
      child: PhysicalPressable(
        onTap: onTap,
        color: backgroundColor ?? theme.colorScheme.surface,
        material: PhysicalMaterial.bead,
        child: Center(child: icon),
      ),
    );
  }
}
