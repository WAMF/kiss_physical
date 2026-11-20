import 'package:flutter/material.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

class _Bar {
  static const height = 12.0;
  static const percent = 100;
  static const fillCurve = Curves.easeOut;
}

/// A glossy bar filling a recessed track in proportion to [fraction].
///
/// The fill glides to each new [fraction], so frequent updates such as a file
/// upload read as continuous movement.
class PhysicalProgressBar extends StatelessWidget {
  /// Creates a bar filled to [fraction].
  const PhysicalProgressBar({
    required this.fraction,
    required this.barColor,
    required this.trackColor,
    this.height = _Bar.height,
    this.barMaterial = PhysicalMaterial.gloss,
    this.trackMaterial = PhysicalMaterial.well,
    this.fillDuration = defaultFillDuration,
    this.semanticLabel,
    super.key,
  });

  /// How long the fill takes to glide to a new [fraction] unless another
  /// is given.
  static const defaultFillDuration = Duration(milliseconds: 250);

  /// How much of the track is filled, from 0 to 1. Values outside that range
  /// are clamped.
  final double fraction;

  /// The colour of the filled part.
  final Color barColor;

  /// The colour of the recessed track.
  final Color trackColor;

  /// The thickness of the track in logical pixels.
  final double height;

  /// How the filled part is shaped and catches the light. A texture on it
  /// is tinted to [barColor].
  final PhysicalMaterial barMaterial;

  /// How the recessed track is shaped and catches the light. A texture on
  /// it is tinted to [trackColor].
  final PhysicalMaterial trackMaterial;

  /// How long the fill takes to glide to a new [fraction]. At
  /// [Duration.zero] it follows the fraction at once, as it must under
  /// something dragged along it.
  final Duration fillDuration;

  /// What the bar is called by screen readers, which also hear how full it
  /// is as a percentage.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final filled = fraction.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(filled * _Bar.percent).round()}%',
      child: _Track(
        filled: filled,
        height: height,
        barColor: barColor,
        trackColor: trackColor,
        barMaterial: barMaterial.tintedTo(barColor),
        trackMaterial: trackMaterial.tintedTo(trackColor),
        fillDuration: fillDuration,
      ),
    );
  }
}

/// The recessed track and the bar that glides along it to [filled].
class _Track extends StatelessWidget {
  const _Track({
    required this.filled,
    required this.height,
    required this.barColor,
    required this.trackColor,
    required this.barMaterial,
    required this.trackMaterial,
    required this.fillDuration,
  });

  final double filled;
  final double height;
  final Color barColor;
  final Color trackColor;
  final PhysicalMaterial barMaterial;
  final PhysicalMaterial trackMaterial;
  final Duration fillDuration;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: PhysicalSurface(
        color: trackColor,
        material: trackMaterial,
        borderRadius: PhysicalSurface.stadium,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: filled),
          duration: fillDuration,
          curve: _Bar.fillCurve,
          builder: (context, filled, fill) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(widthFactor: filled, child: fill),
          ),
          child: PhysicalSurface(
            color: barColor,
            material: barMaterial,
            borderRadius: PhysicalSurface.stadium,
            textureAlignment: AlignmentDirectional.centerStart,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
