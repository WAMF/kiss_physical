import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kiss_physical/src/components/physical_defaults.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

class _Spin {
  static const lap = Duration(milliseconds: 1100);
  static const calmLap = Duration(seconds: 6);

  /// How much the bead hurries through the bottom of the dish and lingers
  /// at the top, as a share of a lap.
  static const swing = 0.08;

  /// The width of the bead as a share of the width of the dish.
  static const beadShare = 0.28;

  /// The gap between the bead and the wall of the dish, as a share of the
  /// width of the dish.
  static const insetShare = 0.06;
  static const turn = math.pi * 2;
}

/// A bead rolling round a shallow dish, for work whose length is not
/// known.
///
/// The bead hurries through the bottom of the dish and lingers at the top.
/// With reduced motion it rolls slowly, so it still shows that something
/// is happening.
class PhysicalSpinner extends StatefulWidget {
  /// Creates a dish of [diameter] with a bead of [beadColor] rolling in it.
  const PhysicalSpinner({
    required this.beadColor,
    this.diameter = defaultDiameter,
    this.dishColor,
    this.dishMaterial = PhysicalMaterial.well,
    this.beadMaterial = PhysicalMaterial.bead,
    this.semanticLabel,
    super.key,
  });

  /// The width and height of the dish unless another is given.
  static const defaultDiameter = 40.0;

  /// The colour of the bead.
  final Color beadColor;

  /// The width and height of the dish in logical pixels.
  final double diameter;

  /// The colour of the dish. Defaults to the secondary background of the
  /// nearest `SemanticColors`, or the surface colour of the theme.
  final Color? dishColor;

  /// How the dish is shaped and catches the light. A texture on it is
  /// tinted to the colour of the dish.
  final PhysicalMaterial dishMaterial;

  /// How the bead is shaped and catches the light. A texture on it is
  /// tinted to [beadColor].
  final PhysicalMaterial beadMaterial;

  /// What screen readers say is happening, such as "Loading".
  final String? semanticLabel;

  @override
  State<PhysicalSpinner> createState() => _PhysicalSpinnerState();
}

class _PhysicalSpinnerState extends State<PhysicalSpinner>
    with SingleTickerProviderStateMixin {
  late final _lap = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isCalm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = isCalm ? _Spin.calmLap : _Spin.lap;
    if (_lap.duration == duration) return;
    _lap
      ..duration = duration
      ..repeat();
  }

  @override
  void dispose() {
    _lap.dispose();
    super.dispose();
  }

  /// Where on the rim the bead is, with (0, 1) the bottom of the dish.
  Alignment _placeAt(double lap) {
    final angle = (lap + _Spin.swing * math.sin(lap * _Spin.turn)) * _Spin.turn;
    return Alignment(math.sin(angle), -math.cos(angle));
  }

  @override
  Widget build(BuildContext context) {
    final dish = widget.dishColor ?? PhysicalDefaults.surfaceColor(context);
    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: widget.diameter,
        child: PhysicalSurface(
          color: dish,
          material: widget.dishMaterial.tintedTo(dish),
          borderRadius: PhysicalSurface.stadium,
          child: Padding(
            padding: EdgeInsets.all(widget.diameter * _Spin.insetShare),
            child: AnimatedBuilder(
              animation: _lap,
              builder: (context, bead) => Align(
                alignment: _placeAt(_lap.value),
                child: bead,
              ),
              child: SizedBox.square(
                dimension: widget.diameter * _Spin.beadShare,
                child: PhysicalSurface(
                  color: widget.beadColor,
                  material: widget.beadMaterial.tintedTo(widget.beadColor),
                  borderRadius: PhysicalSurface.stadium,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
