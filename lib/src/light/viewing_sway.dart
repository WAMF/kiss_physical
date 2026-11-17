import 'dart:ui';

/// Turns the way a device is being tilted into how far the viewer has moved
/// off its usual line of sight, for shifting layers that lie beneath the
/// screen.
///
/// The usual line of sight is whatever pose the device has been held in
/// lately: it follows the tilt slowly, so a new resting pose becomes the
/// centre again and only fresh movement shows.
class ViewingSway {
  /// Creates a sway that settles by [settling] and reaches at most [reach].
  ViewingSway({
    this.settling = defaultSettling,
    this.reach = defaultReach,
  })  : assert(settling > 0 && settling <= 1, 'settling must be in (0, 1]'),
        assert(reach >= 0, 'reach must not be negative');

  /// Share of the way the resting pose moves towards each new tilt.
  static const defaultSettling = 0.03;

  /// Longest sway reported, as the sine of the angle off the line of sight.
  static const defaultReach = 0.35;

  /// Share of the way the resting pose moves towards each new tilt.
  final double settling;

  /// Longest sway reported, as the sine of the angle off the line of sight.
  final double reach;

  Offset? _restingTilt;

  /// Feeds the up direction projected on the screen and returns the sway:
  /// the direction, on the screen, of the side now nearer the viewer.
  Offset follow(Offset tilt) {
    final resting = _restingTilt ?? tilt;
    final sway = _limited(tilt - resting);
    _restingTilt = resting + (tilt - resting) * settling;
    return sway;
  }

  /// Forgets the resting pose so the next tilt defines it.
  void reset() => _restingTilt = null;

  Offset _limited(Offset sway) {
    final distance = sway.distance;
    return distance > reach ? sway * (reach / distance) : sway;
  }
}
