import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/motion/physical_feel.dart';

/// An animation moved by springs, which can be sent somewhere new at any
/// moment and carries the speed it already has into the new movement.
///
/// Its value is not held between 0 and 1: a spring that bounces carries it
/// a little past where it is going.
class SpringController extends AnimationController {
  /// Creates a controller resting at [value].
  SpringController({required super.vsync, super.value}) : super.unbounded();

  /// Sends the value towards [target] on [spring], keeping its speed, or
  /// setting off at [velocity] when one is given. Once within [tolerance]
  /// of [target] and as nearly still, the value rests exactly on it.
  TickerFuture springTo(
    double target, {
    required SpringDescription spring,
    double? velocity,
    Tolerance tolerance = PhysicalFeel.settled,
  }) {
    return animateWith(
      ScrollSpringSimulation(
        spring,
        value,
        target,
        velocity ?? this.velocity,
        tolerance: tolerance,
      ),
    );
  }
}
