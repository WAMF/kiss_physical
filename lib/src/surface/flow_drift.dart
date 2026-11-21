import 'dart:ui';

/// How far something carried by gravity has streamed, and which way it is
/// streaming now, as the flames of a fire do.
///
/// The surface shader moves such things by sliding a pattern along the way
/// they travel. Were that slide worked out from the present direction and
/// the time alone, turning the direction would swing everything they had
/// ever travelled round with it, and they would race. So the travel is
/// added up a frame at a time here: a turn only bends where they go next,
/// at the pace they were already keeping.
class FlowDrift {
  Offset _down = _Drift.upright;
  Offset _travelled = Offset.zero;
  double _standing = 1;
  bool _hasDirection = false;
  bool _hasStanding = false;

  /// The unit direction of down, eased towards gravity.
  Offset get down => _down;

  /// The path streamed along so far, in seconds of travel down it.
  Offset get travelled => _travelled;

  /// How far the flow has room to rise across the screen, as a share of
  /// its full height.
  ///
  /// A screen stood on edge gives it all the room there is. One lying flat
  /// has up pointing out of the glass, so the flow rises towards the viewer
  /// and only a little of it shows across the screen.
  double get rise => _Drift.flatRise + (1 - _Drift.flatRise) * _standing;

  /// Moves the flow on by [seconds] with gravity pulling along [gravity],
  /// the part of the real pull that lies in the plane of the screen.
  ///
  /// The direction eases round to a new gravity over a moment, and holds
  /// while gravity is too weak to say which way is down. [whenFlat] is a
  /// slight pull added to settle the direction on a screen lying flat; it
  /// does not count towards the [rise].
  void advance(
    double seconds,
    Offset gravity, {
    Offset whenFlat = Offset.zero,
  }) {
    final easing = (seconds * _Drift.turning).clamp(0.0, 1.0);
    final steering = gravity + whenFlat;
    final pull = steering.distance;
    if (pull > _Drift.leastPull) {
      final wanted = steering / pull;
      final share = _hasDirection ? easing : 1.0;
      _down = _unit(_down + (wanted - _down) * share, orElse: wanted);
      _hasDirection = true;
    }
    final standing = gravity.distance.clamp(0.0, 1.0);
    _standing += (standing - _standing) * (_hasStanding ? easing : 1.0);
    _hasStanding = true;
    final step = seconds.clamp(0.0, _Drift.longestStep);
    _travelled += _down * step;
    if (_travelled.distance > _Drift.furthest) _travelled = Offset.zero;
  }

  static Offset _unit(Offset direction, {required Offset orElse}) {
    final length = direction.distance;
    return length < _Drift.leastPull ? orElse : direction / length;
  }
}

class _Drift {
  static const upright = Offset(0, 1);
  static const turning = 5.0;
  static const leastPull = 0.001;

  /// The share of its height a flow keeps on a screen lying flat.
  static const flatRise = 0.2;
  static const longestStep = 0.1;

  /// Keeps the travel small enough for the shader to stay precise.
  static const furthest = 3600.0;
}
