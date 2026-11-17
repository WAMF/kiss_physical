import 'package:flutter/material.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

/// Drives the push-in animation shared by pressable physical surfaces.
class _PressController extends AnimationController {
  _PressController({required super.vsync})
      : super(duration: _down, reverseDuration: _up);

  static const _down = Duration(milliseconds: 70);
  static const _up = Duration(milliseconds: 220);

  late final Animation<double> travel = CurvedAnimation(
    parent: this,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOutBack.flipped,
  );

  void setPressed({required bool pressed}) {
    if (pressed) {
      forward();
    } else {
      reverse();
    }
  }
}

/// A [PhysicalSurface] that sinks under the finger and springs back.
class PhysicalPressable extends StatefulWidget {
  /// Creates a pressable surface of [color] around [child].
  const PhysicalPressable({
    required this.onTap,
    required this.color,
    required this.child,
    this.material = PhysicalMaterial.gloss,
    this.borderRadius = PhysicalSurface.stadium,
    this.semanticLabel,
    super.key,
  });

  /// Called on tap. The surface is inert when null.
  final VoidCallback? onTap;

  /// The base colour of the surface.
  final Color color;

  /// What sits on the surface.
  final Widget child;

  /// How the surface is shaped and how it catches the light.
  final PhysicalMaterial material;

  /// The corner radii of the surface.
  final BorderRadius borderRadius;

  /// What the button is called by screen readers.
  final String? semanticLabel;

  @override
  State<PhysicalPressable> createState() => _PhysicalPressableState();
}

class _PhysicalPressableState extends State<PhysicalPressable>
    with SingleTickerProviderStateMixin {
  late final _press = _PressController(vsync: this);

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => _press.setPressed(pressed: true) : null,
        onTapUp: enabled ? (_) => _press.setPressed(pressed: false) : null,
        onTapCancel: enabled ? () => _press.setPressed(pressed: false) : null,
        child: PhysicalSurface(
          color: widget.color,
          material: widget.material,
          borderRadius: widget.borderRadius,
          press: _press.travel,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Background for Material buttons that renders them as a pressable
/// [PhysicalSurface]. Use through [physicalButtonStyle].
class PhysicalButtonBackground extends StatefulWidget {
  /// Creates a button background of [color] around [child].
  const PhysicalButtonBackground({
    required this.color,
    required this.isPressed,
    required this.child,
    this.material = PhysicalMaterial.gloss,
    this.borderRadius = PhysicalSurface.stadium,
    super.key,
  });

  /// The base colour of the button.
  final Color color;

  /// Whether the button is held down, so the surface sinks.
  final bool isPressed;

  /// The label of the button.
  final Widget child;

  /// How the button is shaped and how it catches the light.
  final PhysicalMaterial material;

  /// The corner radii of the button.
  final BorderRadius borderRadius;

  @override
  State<PhysicalButtonBackground> createState() =>
      _PhysicalButtonBackgroundState();
}

class _PhysicalButtonBackgroundState extends State<PhysicalButtonBackground>
    with SingleTickerProviderStateMixin {
  late final _press = _PressController(vsync: this);

  @override
  void didUpdateWidget(PhysicalButtonBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPressed != widget.isPressed) {
      _press.setPressed(pressed: widget.isPressed);
    }
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PhysicalSurface(
      color: widget.color,
      material: widget.material,
      borderRadius: widget.borderRadius,
      press: _press.travel,
      child: widget.child,
    );
  }
}

/// A [ButtonStyle] that turns any Material button into a physical pill of
/// the given [color], keeping the button's own focus, semantics and sizing.
ButtonStyle physicalButtonStyle({
  required Color color,
  required Color foregroundColor,
  PhysicalMaterial material = PhysicalMaterial.gloss,
  Size? minimumSize,
  TextStyle? textStyle,
}) {
  const clear = WidgetStatePropertyAll(Colors.transparent);
  return ButtonStyle(
    backgroundColor: clear,
    shadowColor: clear,
    surfaceTintColor: clear,
    overlayColor: clear,
    elevation: const WidgetStatePropertyAll(0),
    splashFactory: NoSplash.splashFactory,
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    minimumSize:
        minimumSize == null ? null : WidgetStatePropertyAll(minimumSize),
    textStyle: textStyle == null ? null : WidgetStatePropertyAll(textStyle),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? foregroundColor.withValues(alpha: _Disabled.foregroundAlpha)
          : foregroundColor,
    ),
    backgroundBuilder: (context, states, child) {
      final isDisabled = states.contains(WidgetState.disabled);
      return PhysicalButtonBackground(
        color: isDisabled ? _Disabled.frosted(color) : color,
        material: isDisabled ? _Disabled.flattened(material) : material,
        isPressed: states.contains(WidgetState.pressed),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

/// How a button looks when it cannot be pressed: frosted over, so its
/// colour is greyed and its shine, dome and shadow are gone.
class _Disabled {
  static const foregroundAlpha = 0.45;

  /// The grey a disabled button's colour is drawn towards.
  static const _frost = Color(0xFF5E5D63);

  /// Share of the way the colour moves to [_frost].
  static const _frostAmount = 0.72;
  static const _roughness = 0.95;
  static const _reliefScale = 0.35;

  static Color frosted(Color color) {
    return Color.lerp(color, _frost, _frostAmount)!.withValues(alpha: color.a);
  }

  static PhysicalMaterial flattened(PhysicalMaterial material) {
    return material.copyWith(
      roughness: _roughness,
      specularTint: 0,
      crown: 0,
      relief: material.relief * _reliefScale,
      elevation: 0,
    );
  }
}
