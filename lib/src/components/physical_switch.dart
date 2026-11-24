import 'package:flutter/material.dart';
import 'package:kiss_physical/src/material/disabled_look.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/motion/physical_feel.dart';
import 'package:kiss_physical/src/motion/physical_haptics.dart';
import 'package:kiss_physical/src/motion/physical_motion.dart';
import 'package:kiss_physical/src/motion/spring_controller.dart';
import 'package:kiss_physical/src/surface/focus_ring.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

class _Switch {
  static const off = 0.0;
  static const on = 1.0;
  static const rests = [off, on];

  /// The gap between the bead and the wall of its track.
  static const inset = 3.0;

  static double restOf({required bool value}) => value ? on : off;
}

/// A bead in a recessed track that is slid, thrown or tapped from off to
/// on, the track taking its [activeColor] as the bead crosses.
///
/// The bead moves on the spring of what it is made of and gives a little
/// at either end. With keyboard focus, Enter and Space flip it. With no
/// [onChanged] the switch is frosted over and inert.
class PhysicalSwitch extends StatefulWidget {
  /// Creates a switch showing [value].
  const PhysicalSwitch({
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.trackColor,
    required this.thumbColor,
    this.width = defaultWidth,
    this.height = defaultHeight,
    this.trackMaterial = PhysicalMaterial.well,
    this.thumbMaterial = PhysicalMaterial.bead,
    this.semanticLabel,
    this.focusNode,
    super.key,
  }) : assert(width > height, 'a switch must be wider than it is tall');

  /// The length of the track unless another is given.
  static const defaultWidth = 56.0;

  /// The height of the track unless another is given.
  static const defaultHeight = 32.0;

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value when the switch is flipped. The switch is
  /// frosted over and inert when null.
  final ValueChanged<bool>? onChanged;

  /// The colour of the track when the switch is on.
  final Color activeColor;

  /// The colour of the track when the switch is off.
  final Color trackColor;

  /// The colour of the bead.
  final Color thumbColor;

  /// The length of the track in logical pixels.
  final double width;

  /// The height of the track in logical pixels.
  final double height;

  /// How the recessed track is shaped and catches the light. A texture on
  /// it is tinted to the colour the track shows.
  final PhysicalMaterial trackMaterial;

  /// How the bead is shaped and catches the light, and what it feels like
  /// to move. A texture on it is tinted to [thumbColor].
  final PhysicalMaterial thumbMaterial;

  /// What the switch is called by screen readers.
  final String? semanticLabel;

  /// Controls the keyboard focus of the switch, or null for one of its own.
  final FocusNode? focusNode;

  @override
  State<PhysicalSwitch> createState() => _PhysicalSwitchState();
}

class _PhysicalSwitchState extends State<PhysicalSwitch>
    with SingleTickerProviderStateMixin {
  late final _position = SpringController(
    vsync: this,
    value: _Switch.restOf(value: widget.value),
  );
  final _showsFocus = ValueNotifier<bool>(false);

  /// Where the finger has carried the bead during the drag in progress.
  var _dragged = _Switch.off;

  PhysicalFeel get _feel => PhysicalFeel.of(widget.thumbMaterial);

  double get _travel => widget.width - widget.height;

  @override
  void didUpdateWidget(PhysicalSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _settle();
  }

  @override
  void dispose() {
    _position.dispose();
    _showsFocus.dispose();
    super.dispose();
  }

  void _settle({double? velocity}) {
    _position.springTo(
      _Switch.restOf(value: widget.value),
      spring: _feel.release,
      velocity: velocity,
    );
  }

  void _choose({required bool value}) {
    if (value == widget.value) return;
    PhysicalHaptics.play(context, _feel.haptic);
    widget.onChanged?.call(value);
  }

  void _startDrag() => _dragged = _position.value;

  void _drag(double towardsOn) {
    _dragged += towardsOn / _travel;
    _position.value = _dragged;
  }

  void _endDrag(double velocityTowardsOn) {
    final velocity = velocityTowardsOn / _travel;
    final rest = PhysicalMotion.stopFor(
      _position.value,
      velocity,
      _Switch.rests,
    );
    _settle(velocity: velocity);
    _choose(value: rest == _Switch.on);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onChanged != null;
    final towardsOn =
        Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    void toggle() => _choose(value: !widget.value);
    return FocusableActionDetector(
      enabled: isEnabled,
      focusNode: widget.focusNode,
      mouseCursor: isEnabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (shows) => _showsFocus.value = shows,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => toggle(),
        ),
      },
      child: Semantics(
        toggled: widget.value,
        enabled: isEnabled,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isEnabled ? toggle : null,
          onHorizontalDragStart: isEnabled ? (_) => _startDrag() : null,
          onHorizontalDragUpdate: isEnabled
              ? (details) => _drag(details.primaryDelta! * towardsOn)
              : null,
          onHorizontalDragEnd: isEnabled
              ? (details) => _endDrag(details.primaryVelocity! * towardsOn)
              : null,
          child: PhysicalFocusRing(
            isShown: _showsFocus,
            borderRadius: PhysicalSurface.stadium,
            child: AnimatedBuilder(
              animation: _position,
              builder: (context, _) => _SwitchBody(
                position: _position.value,
                isEnabled: isEnabled,
                size: Size(widget.width, widget.height),
                activeColor: widget.activeColor,
                trackColor: widget.trackColor,
                thumbColor: widget.thumbColor,
                trackMaterial: widget.trackMaterial,
                thumbMaterial: widget.thumbMaterial,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The track and the bead at [position] along it, from off at 0 to on at
/// 1. Past either end the bead gives a little and is held by the track.
class _SwitchBody extends StatelessWidget {
  const _SwitchBody({
    required this.position,
    required this.isEnabled,
    required this.size,
    required this.activeColor,
    required this.trackColor,
    required this.thumbColor,
    required this.trackMaterial,
    required this.thumbMaterial,
  });

  final double position;
  final bool isEnabled;
  final Size size;
  final Color activeColor;
  final Color trackColor;
  final Color thumbColor;
  final PhysicalMaterial trackMaterial;
  final PhysicalMaterial thumbMaterial;

  Color _shown(Color color) {
    return isEnabled ? color : DisabledLook.frosted(color);
  }

  PhysicalMaterial _made(PhysicalMaterial material, Color color) {
    final tinted = material.tintedTo(color);
    return isEnabled ? tinted : DisabledLook.flattened(tinted);
  }

  @override
  Widget build(BuildContext context) {
    final crossed = position.clamp(_Switch.off, _Switch.on);
    final held = PhysicalMotion.heldWithin(
      position,
      lowest: _Switch.off,
      highest: _Switch.on,
    );
    final track = _shown(Color.lerp(trackColor, activeColor, crossed)!);
    final thumb = _shown(thumbColor);
    return SizedBox.fromSize(
      size: size,
      child: PhysicalSurface(
        color: track,
        material: _made(trackMaterial, track),
        borderRadius: PhysicalSurface.stadium,
        child: Padding(
          padding: const EdgeInsets.all(_Switch.inset),
          child: Align(
            alignment: AlignmentDirectional(held * 2 - 1, 0),
            child: AspectRatio(
              aspectRatio: 1,
              child: PhysicalSurface(
                color: thumb,
                material: _made(thumbMaterial, thumb),
                borderRadius: PhysicalSurface.stadium,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
