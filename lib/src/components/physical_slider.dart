import 'package:flutter/material.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

class _Slider {
  static const thumbDiameter = 32.0;
  static const trackHeight = 12.0;
  static const keyboardSteps = 20;
  static const spokenDecimals = 2;
}

/// A bead that slides along a recessed track to pick a value between [min]
/// and [max], leaving a glossy bar behind it.
///
/// Dragging anywhere along the track, or tapping it, moves the bead there.
class PhysicalSlider extends StatelessWidget {
  /// Creates a slider showing [value] between [min] and [max].
  const PhysicalSlider({
    required this.value,
    required this.onChanged,
    required this.barColor,
    required this.trackColor,
    required this.thumbColor,
    this.min = 0,
    this.max = 1,
    this.divisions,
    super.key,
  }) : assert(max > min, 'max must be greater than min');

  /// The chosen value. Values outside [min] to [max] are clamped.
  final double value;

  /// Called with the new value as the bead is moved.
  final ValueChanged<double> onChanged;

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

  double get _fraction => ((value - min) / (max - min)).clamp(0.0, 1.0);

  double _valueAt(double fraction) {
    final steps = divisions;
    final clamped = fraction.clamp(0.0, 1.0);
    final snapped = steps == null ? clamped : (clamped * steps).round() / steps;
    return min + snapped * (max - min);
  }

  void _moveTo(double fraction) {
    final next = _valueAt(fraction);
    if (next != value) onChanged(next);
  }

  double _stepped(int direction) {
    return _fraction + direction / (divisions ?? _Slider.keyboardSteps);
  }

  static String _spoken(double value) {
    return value.toStringAsFixed(_Slider.spokenDecimals);
  }

  @override
  Widget build(BuildContext context) {
    final isRightToLeft = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      slider: true,
      value: _spoken(value),
      increasedValue: _spoken(_valueAt(_stepped(1))),
      decreasedValue: _spoken(_valueAt(_stepped(-1))),
      onIncrease: () => _moveTo(_stepped(1)),
      onDecrease: () => _moveTo(_stepped(-1)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travel = constraints.maxWidth - _Slider.thumbDiameter;
          void moveToPosition(Offset position) {
            final along = (position.dx - _Slider.thumbDiameter / 2) / travel;
            _moveTo(isRightToLeft ? 1 - along : along);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => moveToPosition(details.localPosition),
            onHorizontalDragStart: (details) =>
                moveToPosition(details.localPosition),
            onHorizontalDragUpdate: (details) =>
                moveToPosition(details.localPosition),
            child: SizedBox(
              height: _Slider.thumbDiameter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _Track(
                    filledWidth: _Slider.thumbDiameter / 2 + _fraction * travel,
                    barColor: barColor,
                    trackColor: trackColor,
                  ),
                  Align(
                    alignment: AlignmentDirectional(_fraction * 2 - 1, 0),
                    child: _Thumb(color: thumbColor),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.filledWidth,
    required this.barColor,
    required this.trackColor,
  });

  final double filledWidth;
  final Color barColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _Slider.trackHeight,
      child: PhysicalSurface(
        color: trackColor,
        material: PhysicalMaterial.well,
        borderRadius: PhysicalSurface.stadium,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: filledWidth,
            child: PhysicalSurface(
              color: barColor,
              material: PhysicalMaterial.gloss,
              borderRadius: PhysicalSurface.stadium,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _Slider.thumbDiameter,
      child: PhysicalSurface(
        color: color,
        material: PhysicalMaterial.bead,
        borderRadius: PhysicalSurface.stadium,
        child: const SizedBox.expand(),
      ),
    );
  }
}
