import 'package:flutter/material.dart';
import 'package:kiss_physical/src/components/physical_defaults.dart';
import 'package:kiss_physical/src/material/disabled_look.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_pressable.dart';

/// A round physical button that sinks when pressed.
///
/// With no [onPressed] it is frosted over and inert.
class PhysicalIconButton extends StatelessWidget {
  /// Creates a round button showing [icon].
  const PhysicalIconButton({
    required this.icon,
    required this.diameter,
    required this.onPressed,
    this.color,
    this.material = PhysicalMaterial.bead,
    this.semanticLabel,
    this.tooltip,
    super.key,
  });

  /// What is shown at the centre of the button.
  final Widget icon;

  /// The width and height of the button in logical pixels.
  final double diameter;

  /// Called on tap, and on Enter or Space while focused. The button is
  /// frosted over and inert when null.
  final VoidCallback? onPressed;

  /// The colour of the button. Defaults to the secondary background of the
  /// nearest `SemanticColors`, or the surface colour of the theme.
  final Color? color;

  /// How the button is shaped and how it catches the light.
  final PhysicalMaterial material;

  /// What the button is called by screen readers. An icon alone says
  /// nothing to them, so give this or a [tooltip].
  final String? semanticLabel;

  /// Text shown on a long press or under a resting pointer, and read by
  /// screen readers when there is no [semanticLabel].
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final resting = color ?? PhysicalDefaults.surfaceColor(context);
    final shown = isEnabled ? resting : DisabledLook.frosted(resting);
    final made = material.tintedTo(shown);
    final button = SizedBox.square(
      dimension: diameter,
      child: PhysicalPressable(
        onTap: onPressed,
        color: shown,
        material: isEnabled ? made : DisabledLook.flattened(made),
        semanticLabel: semanticLabel ?? tooltip,
        child: Center(
          child: isEnabled
              ? icon
              : Opacity(opacity: DisabledLook.foregroundAlpha, child: icon),
        ),
      ),
    );
    final message = tooltip;
    if (message == null) return button;
    return Tooltip(
      message: message,
      excludeFromSemantics: true,
      child: button,
    );
  }
}
