import 'dart:math' as math;
import 'dart:ui';

/// The surface of a liquid in a vessel, without simulating the liquid.
///
/// The surface is a flat plane that swings like a damped pendulum to stay
/// level against gravity, so it overshoots and rocks when gravity turns.
/// How fast it is swinging stirs up [agitation], which drives ripples and
/// bubbles and dies away once it rests. Shaking also whips up [foam], a
/// head that builds quickly and takes much longer to settle.
class LiquidSlosh {
  double _angle = _Rest.angle;
  double _velocity = 0;
  double _agitation = 0;
  double _foam = 0;
  bool _hasSettledOnce = false;

  /// The direction the surface faces: away from gravity once at rest.
  Offset get surfaceUp => Offset(math.cos(_angle), math.sin(_angle));

  /// How disturbed the liquid is, from 0 (still) to 1.
  double get agitation => _agitation;

  /// How much of a head of foam is standing on the liquid, from 0 to 1.
  double get foam => _foam;

  /// Moves the surface on by [seconds] under [gravity], which points down
  /// within the plane of the screen. With no gravity in that plane, as in a
  /// vessel lying flat, the surface stays where it was.
  void advance(double seconds, Offset gravity) {
    if (gravity.distance < _Spring.leastGravity) {
      _calm(seconds);
      return;
    }
    final level = math.atan2(-gravity.dy, -gravity.dx);
    if (!_hasSettledOnce) {
      _angle = level;
      _hasSettledOnce = true;
      return;
    }
    var remaining = math.min(seconds, _Spring.longestAdvance);
    while (remaining > 0) {
      final step = math.min(remaining, _Spring.step);
      _swing(step, level);
      remaining -= step;
    }
    _calm(seconds);
  }

  /// Shakes the liquid by [amount], from 0 to 1.
  void disturb(double amount) {
    _agitation = math.min(_agitation + amount, 1);
    _velocity += amount * _Spring.shakeKick;
  }

  void _swing(double step, double level) {
    final offLevel = _wrapped(_angle - level);
    final acceleration =
        -_Spring.stiffness * offLevel - _Spring.damping * _velocity;
    _velocity += acceleration * step;
    _angle += _velocity * step;
    _agitation = math.min(
      _agitation + _velocity.abs() * step * _Spring.stirring,
      1,
    );
  }

  void _calm(double seconds) {
    _agitation *= math.exp(-seconds * _Spring.calming);
    if (_agitation > _foam) {
      _foam += (_agitation - _foam) *
          math.min(1, seconds * _Foam.whipping).toDouble();
    } else {
      _foam *= math.exp(-seconds * _Foam.settling);
    }
  }

  static double _wrapped(double angle) {
    return math.atan2(math.sin(angle), math.cos(angle));
  }
}

class _Foam {
  static const whipping = 3.0;
  static const settling = 0.22;
}

class _Rest {
  static const angle = -math.pi / 2;
}

class _Spring {
  static const stiffness = 60.0;
  static const damping = 4.0;
  static const stirring = 0.9;
  static const calming = 1.2;
  static const shakeKick = 6.0;
  static const step = 1 / 240;
  static const longestAdvance = 1 / 15;
  static const leastGravity = 0.02;
}
