import 'package:flutter/material.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

class _Bar {
  static const height = 12.0;
  static const percent = 100;
  static const fillDuration = Duration(milliseconds: 250);
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
    this.semanticLabel,
    super.key,
  });

  /// How much of the track is filled, from 0 to 1. Values outside that range
  /// are clamped.
  final double fraction;

  /// The colour of the filled part.
  final Color barColor;

  /// The colour of the recessed track.
  final Color trackColor;

  /// The thickness of the track in logical pixels.
  final double height;

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
  });

  final double filled;
  final double height;
  final Color barColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: PhysicalSurface(
        color: trackColor,
        material: PhysicalMaterial.well,
        borderRadius: PhysicalSurface.stadium,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: filled),
          duration: _Bar.fillDuration,
          curve: _Bar.fillCurve,
          builder: (context, filled, fill) => FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: filled,
            child: fill,
          ),
          child: PhysicalSurface(
            color: barColor,
            material: PhysicalMaterial.gloss,
            borderRadius: PhysicalSurface.stadium,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
