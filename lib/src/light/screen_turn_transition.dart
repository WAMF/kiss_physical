import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:kiss_physical/src/light/up_vector_filter.dart';

/// Keeps directions true to the world while the interface turns to a new
/// [ScreenTurn].
///
/// The system does not turn the interface at once: it swings the picture
/// round over a moment. A direction given in the new turn from the first
/// frame would be swung round with the picture and point the wrong way
/// until the swing ends. This holds each direction back by the part of the
/// swing still to come, so that on the glass it never moves.
class ScreenTurnTransition {
  /// Creates a transition that follows a swing of [duration] along [curve].
  ScreenTurnTransition({
    this.duration = defaultDuration,
    this.curve = Curves.easeInOut,
  });

  /// How long the system takes to swing the interface round.
  static const defaultDuration = Duration(milliseconds: 400);

  /// How long the system takes to swing the interface round.
  final Duration duration;

  /// How the swing eases from start to end.
  final Curve curve;

  double _lag = 0;

  /// Starts following a swing of the interface from [from] to [to].
  ///
  /// When an earlier swing was still under way, [interruptedAfter] is how
  /// long it had run, so that what was left of it is carried over.
  void begin(ScreenTurn from, ScreenTurn to, {Duration? interruptedAfter}) {
    final carried = interruptedAfter == null ? 0.0 : lagAfter(interruptedAfter);
    _lag = _shortestWay(carried + from.angle - to.angle);
  }

  /// Forgets any swing, as when the interface is shown without one.
  void finish() => _lag = 0;

  /// The angle, in radians clockwise, still to be swung through once
  /// [elapsed] has passed since [begin].
  double lagAfter(Duration elapsed) {
    if (isSettledAfter(elapsed)) return 0;
    final progress = elapsed.inMicroseconds / duration.inMicroseconds;
    return _lag * (1 - curve.transform(progress.clamp(0, 1)));
  }

  /// Whether the interface has come to rest once [elapsed] has passed.
  bool isSettledAfter(Duration elapsed) => _lag == 0 || elapsed >= duration;

  /// Turns [onScreen], a direction in the new turn, to where it must be
  /// drawn once [elapsed] has passed for it to stay put on the glass.
  Offset hold(Offset onScreen, Duration elapsed) {
    final lag = lagAfter(elapsed);
    if (lag == 0) return onScreen;
    final cosine = math.cos(lag);
    final sine = math.sin(lag);
    return Offset(
      onScreen.dx * cosine - onScreen.dy * sine,
      onScreen.dx * sine + onScreen.dy * cosine,
    );
  }

  static double _shortestWay(double angle) {
    final turned = angle.remainder(_Circle.full);
    if (turned > math.pi) return turned - _Circle.full;
    if (turned <= -math.pi) return turned + _Circle.full;
    return turned;
  }
}

class _Circle {
  static const full = 2 * math.pi;
}
