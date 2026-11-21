import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiss_physical/src/components/physical_progress_bar.dart';
import 'package:kiss_physical/src/material/disabled_look.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/focus_ring.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

class _Slider {
  static const keyboardSteps = 20;
  static const spokenDecimals = 2;
}

/// A bead that slides along a recessed track to pick a value between [min]
/// and [max], leaving a glossy bar behind it.
///
/// The track and bar are a `PhysicalProgressBar` filled up to the bead, so
/// the two controls look alike. Each part takes a colour and a material of
/// its own.
///
/// Dragging anywhere along the track, or tapping it, moves the bead there.
/// With keyboard focus the arrow keys move it a step. With no [onChanged]
/// the slider is frosted over and inert.
class PhysicalSlider extends StatefulWidget {
  /// Creates a slider showing [value] between [min] and [max].
  const PhysicalSlider({
    required this.value,
    required this.onChanged,
    required this.barColor,
    required this.trackColor,
    required this.thumbColor,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.thumbDiameter = defaultThumbDiameter,
    this.trackHeight = defaultTrackHeight,
    this.barMaterial = PhysicalMaterial.gloss,
    this.trackMaterial = PhysicalMaterial.well,
    this.thumbMaterial = PhysicalMaterial.bead,
    this.semanticLabel,
    this.focusNode,
    super.key,
  })  : assert(max > min, 'max must be greater than min'),
        assert(
          trackHeight <= thumbDiameter,
          'the track must not be taller than the bead',
        );

  /// The width and height of the bead, which is also the height of the
  /// slider, unless another is given.
  static const defaultThumbDiameter = 32.0;

  /// The thickness of the track unless another is given.
  static const defaultTrackHeight = 12.0;

  /// The chosen value. Values outside [min] to [max] are clamped.
  final double value;

  /// Called with the new value as the bead is moved. The slider is frosted
  /// over and inert when null.
  final ValueChanged<double>? onChanged;

  /// Called with the value the bead was left at when a drag ends.
  final ValueChanged<double>? onChangeEnd;

  /// The colour of the bar left behind the bead.
  final Color barColor;

  /// The colour of the recessed track.
  final Color trackColor;

  /// The colour of the bead.
  final Color thumbColor;

  /// The value at the start of the track.
  final double min;

  /// The value at the end of the track.
  final double max;

  /// How many equal steps the value snaps to, or null to move freely.
  final int? divisions;

  /// The width and height of the bead in logical pixels.
  final double thumbDiameter;

  /// The thickness of the track in logical pixels.
  final double trackHeight;

  /// How the bar left behind the bead is shaped and catches the light. A
  /// texture on it is tinted to [barColor].
  final PhysicalMaterial barMaterial;

  /// How the recessed track is shaped and catches the light. A texture on
  /// it is tinted to [trackColor].
  final PhysicalMaterial trackMaterial;

  /// How the bead is shaped and catches the light. A texture on it is
  /// tinted to [thumbColor].
  final PhysicalMaterial thumbMaterial;

  /// What the slider is called by screen readers.
  final String? semanticLabel;

  /// Controls the keyboard focus of the slider, or null for one of its own.
  final FocusNode? focusNode;

  @override
  State<PhysicalSlider> createState() => _PhysicalSliderState();
}

class _PhysicalSliderState extends State<PhysicalSlider> {
  final _showsFocus = ValueNotifier<bool>(false);

  /// The value the bead was last moved to during the drag in progress.
  double? _lastChosen;

  bool get _isEnabled => widget.onChanged != null;

  double get _fraction {
    final span = widget.max - widget.min;
    return ((widget.value - widget.min) / span).clamp(0.0, 1.0);
  }

  double _valueAt(double fraction) {
    final steps = widget.divisions;
    final clamped = fraction.clamp(0.0, 1.0);
    final snapped = steps == null ? clamped : (clamped * steps).round() / steps;
    return widget.min + snapped * (widget.max - widget.min);
  }

  void _moveTo(double fraction) {
    final next = _valueAt(fraction);
    _lastChosen = next;
    if (next != widget.value) widget.onChanged?.call(next);
  }

  void _endDrag() {
    widget.onChangeEnd?.call(_lastChosen ?? widget.value);
    _lastChosen = null;
  }

  double _stepped(int direction) {
    final steps = widget.divisions ?? _Slider.keyboardSteps;
    return _fraction + direction / steps;
  }

  static String _spoken(double value) {
    return value.toStringAsFixed(_Slider.spokenDecimals);
  }

  @override
  void dispose() {
    _showsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRightToLeft = Directionality.of(context) == TextDirection.rtl;
    final towardsEnd = isRightToLeft ? -1 : 1;
    final isEnabled = _isEnabled;
    return FocusableActionDetector(
      enabled: isEnabled,
      focusNode: widget.focusNode,
      onShowFocusHighlight: (shows) => _showsFocus.value = shows,
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            _StepIntent(towardsEnd),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            _StepIntent(-towardsEnd),
        const SingleActivator(LogicalKeyboardKey.arrowUp): const _StepIntent(1),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const _StepIntent(-1),
      },
      actions: {
        _StepIntent: CallbackAction<_StepIntent>(
          onInvoke: (intent) => _moveTo(_stepped(intent.direction)),
        ),
      },
      child: Semantics(
        slider: true,
        enabled: isEnabled,
        label: widget.semanticLabel,
        value: _spoken(widget.value),
        increasedValue: _spoken(_valueAt(_stepped(1))),
        decreasedValue: _spoken(_valueAt(_stepped(-1))),
        onIncrease: isEnabled ? () => _moveTo(_stepped(1)) : null,
        onDecrease: isEnabled ? () => _moveTo(_stepped(-1)) : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final travel = constraints.maxWidth - widget.thumbDiameter;
            void moveToPosition(Offset position) {
              final along = (position.dx - widget.thumbDiameter / 2) / travel;
              _moveTo(isRightToLeft ? 1 - along : along);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: isEnabled
                  ? (details) => moveToPosition(details.localPosition)
                  : null,
              onHorizontalDragStart: isEnabled
                  ? (details) => moveToPosition(details.localPosition)
                  : null,
              onHorizontalDragUpdate: isEnabled
                  ? (details) => moveToPosition(details.localPosition)
                  : null,
              onHorizontalDragEnd: isEnabled ? (_) => _endDrag() : null,
              child: SizedBox(
                height: widget.thumbDiameter,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ExcludeSemantics(
                      child: PhysicalProgressBar(
                        fraction:
                            (widget.thumbDiameter / 2 + _fraction * travel) /
                                constraints.maxWidth,
                        height: widget.trackHeight,
                        barColor: _shown(widget.barColor),
                        trackColor: widget.trackColor,
                        barMaterial: _shownMaterial(widget.barMaterial),
                        trackMaterial: widget.trackMaterial,
                        fillDuration: Duration.zero,
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional(_fraction * 2 - 1, 0),
                      child: _Thumb(
                        diameter: widget.thumbDiameter,
                        color: _shown(widget.thumbColor),
                        material: _shownMaterial(
                          widget.thumbMaterial
                              .tintedTo(_shown(widget.thumbColor)),
                        ),
                        showsFocus: _showsFocus,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _shown(Color color) {
    return _isEnabled ? color : DisabledLook.frosted(color);
  }

  PhysicalMaterial _shownMaterial(PhysicalMaterial material) {
    return _isEnabled ? material : DisabledLook.flattened(material);
  }
}

/// Moves the bead one step: towards the greater value when [direction] is
/// positive, towards the lesser when it is negative.
class _StepIntent extends Intent {
  const _StepIntent(this.direction);

  final int direction;
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.diameter,
    required this.color,
    required this.material,
    required this.showsFocus,
  });

  final double diameter;
  final Color color;
  final PhysicalMaterial material;
  final ValueNotifier<bool> showsFocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: diameter,
      child: PhysicalFocusRing(
        isShown: showsFocus,
        borderRadius: PhysicalSurface.stadium,
        child: PhysicalSurface(
          color: color,
          material: material,
          borderRadius: PhysicalSurface.stadium,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
