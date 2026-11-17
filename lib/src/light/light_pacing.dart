/// Decides how often the light may change from how fast the device is being
/// moved.
///
/// While the device is swung about, every change is shown at once so the
/// highlights glide. As the movement dies away the wait between changes
/// doubles, step by step, so the small drift of a hand holding the device
/// still costs only a few repaints a second.
class LightPacing {
  /// Creates a pacing that shows every change from [livelySpeed] upwards.
  LightPacing({
    this.livelySpeed = defaultLivelySpeed,
    this.longestWait = defaultLongestWait,
    this.easing = defaultEasing,
  })  : assert(livelySpeed > 0, 'livelySpeed must be positive'),
        assert(easing > 0 && easing <= 1, 'easing must be in (0, 1]');

  /// Speed of the light, in screen-plane units a second, from which every
  /// change is shown at once. About eleven degrees of tilt a second.
  static const defaultLivelySpeed = 0.2;

  /// The wait between changes while the device is all but still.
  static const defaultLongestWait = Duration(milliseconds: 264);

  /// Share of the way the remembered speed falls towards each slower
  /// reading, so the pace drops gradually once movement eases.
  static const defaultEasing = 0.25;

  /// The wait at the first step below [livelySpeed].
  static const _shortestWait = Duration(milliseconds: 33);

  /// Speed of the light, in screen-plane units a second, from which every
  /// change is shown at once.
  final double livelySpeed;

  /// The wait between changes while the device is all but still.
  final Duration longestWait;

  /// Share of the way the remembered speed falls towards each slower
  /// reading.
  final double easing;

  double _speed = 0;

  /// Feeds one movement of the light, [distance] long and [elapsed] after
  /// the one before, and returns how long to wait before showing it.
  Duration follow(double distance, Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final reading = seconds <= 0 ? livelySpeed : distance / seconds;
    _speed = reading > _speed ? reading : _speed + (reading - _speed) * easing;
    return _waitAt(_speed);
  }

  /// Forgets the remembered speed.
  void reset() => _speed = 0;

  Duration _waitAt(double speed) {
    if (speed >= livelySpeed) return Duration.zero;
    var wait = _shortestWait;
    var threshold = livelySpeed / 2;
    while (speed < threshold && wait < longestWait) {
      wait *= 2;
      threshold /= 2;
    }
    return wait < longestWait ? wait : longestWait;
  }
}
