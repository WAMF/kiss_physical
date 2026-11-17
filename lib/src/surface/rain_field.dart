import 'dart:math' as math;
import 'dart:ui';

/// One drop of water on a surface.
///
/// A drop is not a rigid shape. Behind its head it drags a short chain of
/// water, its [wake], each link following the one ahead along the path the
/// drop actually took. The chain draws out as the drop speeds up, bends
/// when it turns, and gathers back into the head when it stops.
class RainDrop {
  RainDrop._(this.position, this.radius, this._phase)
      : _wake = List.filled(_Wake.links, position);

  /// Where the drop is, in the surface's logical pixels.
  Offset position;

  /// How fast it is running, in logical pixels a second.
  Offset velocity = Offset.zero;

  /// Its size in logical pixels.
  double radius;

  final double _phase;
  List<Offset> _wake;

  /// Where the water strung out behind the head lies, nearest link first.
  List<Offset> get wake => _wake;

  /// Lets each link of the wake follow the one ahead of it for [step]
  /// seconds, at a distance that grows with the drop's speed.
  void _dragWake(double step) {
    final haste = math.min(velocity.distance / _Wake.fullSpeed, 1);
    final rest = radius * (_Wake.slack + _Wake.stretch * haste);
    final share = math.min(1, step * _Wake.following).toDouble();
    var ahead = position;
    for (var link = 0; link < _wake.length; link++) {
      final behind = _wake[link] - ahead;
      final gap = behind.distance;
      final wanted = gap > 0 ? ahead + behind / gap * rest : ahead;
      _wake[link] += (wanted - _wake[link]) * share;
      ahead = _wake[link];
    }
  }

  /// Whether the drop is moving fast enough to leave a trail.
  bool get isRunning => velocity.distance > _Run.leastSpeed;
}

/// The drops of water on a surface in the rain, each with a position and a
/// motion of its own.
///
/// Drops land at random and sit where they fall, swelling as more rain
/// gathers into them. One heavy enough for gravity to overcome its grip
/// starts to run, sticking and slipping and
/// wandering a little, sweeping up the drops it meets and shrinking as it
/// leaves water behind. Because each drop carries its own velocity, turning
/// gravity does not turn the pattern: it bends the path of every running
/// drop from where that drop already is.
class RainField {
  /// Creates an empty field; [random] makes its rain repeatable.
  RainField({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  final _drops = <RainDrop>[];
  double _owed = 0;
  double _time = 0;

  /// Every drop now on the surface.
  Iterable<RainDrop> get drops => _drops;

  /// Whether no drops are on the surface.
  bool get isEmpty => _drops.isEmpty;

  /// Puts a drop of [radius] on the surface at [position].
  RainDrop land(Offset position, double radius) {
    final drop = RainDrop._(position, radius, _random.nextDouble());
    _drops.add(drop);
    return drop;
  }

  /// Moves the rain on by [seconds] over a surface of [size].
  ///
  /// [rain] is how hard it is raining, from 0 to 1. [gravity] points down
  /// within the surface, with a length from 0 (lying flat, where nothing
  /// runs) to 1. [slip] is how freely drops run on the body, from 0 (they
  /// stay put) to 1: on a slick body drops let go sooner and run fast and
  /// straight, on one that grips they hang on until they are heavier, then
  /// creep down it in fits and starts, wandering as they go.
  void advance(
    double seconds, {
    required Size size,
    required Offset gravity,
    required double rain,
    double slip = 1,
  }) {
    final pull = math.min(gravity.distance, 1);
    final down = pull > 0 ? gravity / gravity.distance : Offset.zero;
    var remaining = math.min(seconds, _Run.longestAdvance);
    while (remaining > 0) {
      final step = math.min(remaining, _Run.longestStep);
      remaining -= step;
      _time += step;
      _landNewDrops(step, size, rain);
      for (final drop in _drops) {
        _move(
          drop,
          step,
          down,
          drive: math.sqrt(pull * slip),
          grip: 1 - slip.clamp(0.0, 1.0),
          rain: rain,
        );
      }
      _mergeTouching();
      _drops.removeWhere(
        (drop) => drop.radius < _Size.smallest || !_isOn(size, drop),
      );
    }
  }

  void _landNewDrops(double step, Size size, double rain) {
    final area = size.width * size.height / _Fall.areaPerDrop;
    _owed += rain * area * _Fall.dropsPerSecond * step;
    while (_owed >= 1) {
      _owed -= 1;
      if (_drops.length >= _Fall.mostDrops) {
        _swell(_drops[_random.nextInt(_drops.length)]);
        continue;
      }
      final spread = _random.nextDouble();
      land(
        Offset(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
        ),
        _Size.landsFrom + _Size.landsSpread * spread * spread,
      );
    }
  }

  /// Adds a fresh drop's worth of water to [drop], once the surface holds
  /// as many drops as it can.
  void _swell(RainDrop drop) {
    drop.radius = math.min(
      math.sqrt(drop.radius * drop.radius + _Size.landsFrom * _Size.landsFrom),
      _Size.largest,
    );
  }

  void _move(
    RainDrop drop,
    double step,
    Offset down, {
    required double drive,
    required double grip,
    required double rain,
  }) {
    if (drop.radius * drive > _Run.heavyFrom) {
      final stuck = _Run.stuckShare * (1 - grip);
      final surge = stuck +
          (1 - stuck) *
              (0.5 + 0.5 * math.sin(_time * _Run.surgeRate + drop._phase * 7));
      final speed = (_Run.baseSpeed +
              _Run.speedPerRadius * (drop.radius - _Run.heavyFrom)) *
          drive *
          surge;
      final sideways = Offset(-down.dy, down.dx) * _wander(drop, grip);
      final wanted = (down + sideways) * speed;
      drop
        ..velocity += (wanted - drop.velocity) *
            math.min(1, step * _Run.turning).toDouble()
        ..radius -= _Size.shedding * step;
    } else {
      drop
        ..velocity *= math.max(0, 1 - step * _Run.braking).toDouble()
        ..radius = math.min(
          drop.radius + (rain * _Size.gathering - _Size.drying) * step,
          _Size.largest,
        );
    }
    drop
      ..position += drop.velocity * step
      .._dragWake(step);
  }

  /// How far a running drop leans to one side: a slow weave on any body,
  /// with a quicker, larger jitter the more the body grips.
  double _wander(RainDrop drop, double grip) {
    final weave = math.sin(_time * _Run.wanderRate + drop._phase * 11);
    final jitter = math.sin(_time * _Run.jitterRate + drop._phase * 29);
    return _Run.wander * weave + _Run.roughWander * grip * (weave + jitter);
  }

  void _mergeTouching() {
    for (var i = 0; i < _drops.length; i++) {
      final drop = _drops[i];
      if (drop.radius <= 0) continue;
      for (var j = i + 1; j < _drops.length; j++) {
        final other = _drops[j];
        if (other.radius <= 0) continue;
        final reach = (drop.radius + other.radius) * _Size.touching;
        if ((drop.position - other.position).distance > reach) continue;
        _absorb(drop, other);
      }
    }
  }

  void _absorb(RainDrop drop, RainDrop other) {
    final larger = drop.radius >= other.radius ? drop : other;
    drop
      ..position = larger.position
      ..velocity = larger.velocity
      .._wake = larger._wake
      ..radius = math.min(
        math.sqrt(drop.radius * drop.radius + other.radius * other.radius),
        _Size.largest,
      );
    other.radius = 0;
  }

  bool _isOn(Size size, RainDrop drop) {
    return (Offset.zero & size).inflate(drop.radius).contains(drop.position);
  }
}

class _Wake {
  static const links = 4;
  static const slack = 0.1;
  static const stretch = 0.65;
  static const fullSpeed = 160.0;
  static const following = 14.0;
}

class _Fall {
  static const areaPerDrop = 10000.0;
  static const dropsPerSecond = 1.0;
  static const mostDrops = 220;
}

class _Size {
  static const landsFrom = 3.0;
  static const landsSpread = 4.0;
  static const smallest = 1.8;
  static const largest = 14.0;
  static const gathering = 0.3;
  static const touching = 0.8;
  static const shedding = 0.22;
  static const drying = 0.05;
}

class _Run {
  static const heavyFrom = 4.2;
  static const baseSpeed = 75.0;
  static const speedPerRadius = 20.0;
  static const stuckShare = 0.3;
  static const surgeRate = 2.1;
  static const wander = 0.12;
  static const roughWander = 0.45;
  static const jitterRate = 4.7;
  static const wanderRate = 1.3;
  static const turning = 3.5;
  static const braking = 8.0;
  static const leastSpeed = 2.0;
  static const longestStep = 1 / 30;
  static const longestAdvance = 0.5;
}
