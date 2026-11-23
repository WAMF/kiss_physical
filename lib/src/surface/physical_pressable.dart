import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kiss_physical/src/material/disabled_look.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/motion/hold_repeater.dart';
import 'package:kiss_physical/src/motion/physical_feel.dart';
import 'package:kiss_physical/src/motion/physical_haptics.dart';
import 'package:kiss_physical/src/motion/spring_controller.dart';
import 'package:kiss_physical/src/surface/focus_ring.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

class _Travel {
  static const resting = 0.0;
  static const down = 1.0;

  /// How far down a body counts as barely touched when it is let go.
  static const shallow = 0.5;

  /// The downward speed a barely touched body is let go with, so a tap too
  /// quick to carry it down still shows as a dip.
  static const tapKick = 18.0;
}

extension on SpringController {
  void press(PhysicalFeel feel) {
    springTo(_Travel.down, spring: feel.press);
  }

  void letGo(PhysicalFeel feel) {
    final isBarelyTouched = value < _Travel.shallow;
    springTo(
      _Travel.resting,
      spring: feel.release,
      velocity: isBarelyTouched ? math.max(velocity, _Travel.tapKick) : null,
    );
  }

  void setPressed(PhysicalFeel feel, {required bool pressed}) {
    return pressed ? press(feel) : letGo(feel);
  }
}

/// A [PhysicalSurface] that sinks under the finger and springs back.
///
/// How it moves and what the hand feels follow from what it is made of:
/// see [PhysicalFeel]. Wrap it in a [PhysicalHaptics] to keep it quiet.
///
/// It can be reached and pressed from the keyboard, shows a ring while it
/// has keyboard focus, and shows a hand cursor under a mouse. With no
/// [onTap] it is inert and looks as it always does; give it other colours
/// to show that it cannot be pressed.
class PhysicalPressable extends StatefulWidget {
  /// Creates a pressable surface of [color] around [child].
  const PhysicalPressable({
    required this.onTap,
    required this.color,
    required this.child,
    this.material = PhysicalMaterial.gloss,
    this.borderRadius = PhysicalSurface.stadium,
    this.semanticLabel,
    this.feel,
    this.onHold,
    this.repeatsWhileHeld = false,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : assert(
          onHold == null || !repeatsWhileHeld,
          'a held surface either repeats its tap or calls onHold, not both',
        );

  /// Called on tap, and on Enter or Space while focused. The surface is
  /// inert when null.
  final VoidCallback? onTap;

  /// How the surface moves and what the hand feels when it is pressed, or
  /// null for the feel of its [material].
  final PhysicalFeel? feel;

  /// Called when the surface has been held down a while. The surface stays
  /// down until it is let go.
  final VoidCallback? onHold;

  /// Whether [onTap] is called again and again, faster and faster, for as
  /// long as the surface is held. Suited to steppers.
  final bool repeatsWhileHeld;

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

  /// Controls the keyboard focus of the surface, or null for one of its own.
  final FocusNode? focusNode;

  /// Whether the surface takes keyboard focus when it first appears.
  final bool autofocus;

  @override
  State<PhysicalPressable> createState() => _PhysicalPressableState();
}

class _PhysicalPressableState extends State<PhysicalPressable>
    with SingleTickerProviderStateMixin {
  late final _press = SpringController(vsync: this);
  late final _repeater = HoldRepeater(onRepeat: _repeat);
  final _showsFocus = ValueNotifier<bool>(false);

  PhysicalFeel get _feel => widget.feel ?? PhysicalFeel.of(widget.material);

  bool get _hasRepeated => widget.repeatsWhileHeld && _repeater.repeats > 0;

  @override
  void dispose() {
    _repeater.stop();
    _press.dispose();
    _showsFocus.dispose();
    super.dispose();
  }

  void _touch() {
    _press.press(_feel);
    PhysicalHaptics.play(context, _feel.haptic);
    if (widget.repeatsWhileHeld) _repeater.start();
  }

  void _letGo() {
    _repeater.stop();
    _press.letGo(_feel);
  }

  void _tap() {
    if (!_hasRepeated) widget.onTap?.call();
  }

  void _repeat() {
    final onTap = widget.onTap;
    if (onTap == null) return _repeater.stop();
    PhysicalHaptics.play(context, PhysicalHaptic.tick);
    onTap();
  }

  void _hold() {
    _press.press(_feel);
    PhysicalHaptics.play(context, _feel.haptic);
    widget.onHold?.call();
  }

  Future<void> _pressFromKeyboard() async {
    widget.onTap?.call();
    await _press.springTo(_Travel.down, spring: _feel.press);
    if (mounted) _press.letGo(_feel);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final holds = enabled && widget.onHold != null;
    return FocusableActionDetector(
      enabled: enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (shows) => _showsFocus.value = shows,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => _pressFromKeyboard(),
        ),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _tap : null,
          onTapDown: enabled ? (_) => _touch() : null,
          onTapUp: enabled ? (_) => _letGo() : null,
          onTapCancel: enabled ? _letGo : null,
          onLongPressStart: holds ? (_) => _hold() : null,
          onLongPressEnd: holds ? (_) => _letGo() : null,
          onLongPressCancel: holds ? _letGo : null,
          child: PhysicalFocusRing(
            isShown: _showsFocus,
            borderRadius: widget.borderRadius,
            child: PhysicalSurface(
              color: widget.color,
              material: widget.material,
              borderRadius: widget.borderRadius,
              press: _press,
              child: widget.child,
            ),
          ),
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
  late final _press = SpringController(vsync: this);

  @override
  void didUpdateWidget(PhysicalButtonBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPressed == widget.isPressed) return;
    final feel = PhysicalFeel.of(widget.material);
    _press.setPressed(feel, pressed: widget.isPressed);
    if (widget.isPressed) PhysicalHaptics.play(context, feel.haptic);
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
      press: _press,
      child: widget.child,
    );
  }
}

/// A [ButtonStyle] that turns any Material button into a physical pill of
/// the given [color], keeping the button's own focus, semantics and sizing.
/// A texture on [material] is tinted to [color].
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
          ? foregroundColor.withValues(alpha: DisabledLook.foregroundAlpha)
          : foregroundColor,
    ),
    backgroundBuilder: (context, states, child) {
      final isDisabled = states.contains(WidgetState.disabled);
      final shown = isDisabled ? DisabledLook.frosted(color) : color;
      final made = material.tintedTo(shown);
      return PhysicalButtonBackground(
        color: shown,
        material: isDisabled ? DisabledLook.flattened(made) : made,
        isPressed: states.contains(WidgetState.pressed),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}
