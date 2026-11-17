import 'dart:math' as math;
import 'dart:ui';

/// Tracks which way is up, in device axes, by fusing two sensors.
///
/// The gyroscope turns the estimate smoothly and immediately as the device
/// rotates. The accelerometer, which reports up whenever the device is not
/// being shaken, slowly pulls the estimate back so gyroscope drift never
/// accumulates. Changes are reported only once they are large enough to
/// see, so a device at rest reports nothing.
class UpVectorFilter {
  /// Creates a filter that trusts steady accelerometer samples by
  /// [accelerometerTrust] and reports changes larger than [deadband].
  UpVectorFilter({
    this.accelerometerTrust = 0.05,
    this.deadband = 0.006,
  });

  /// Share of each steady accelerometer sample blended into the estimate.
  final double accelerometerTrust;

  /// Smallest change of the reported direction worth reporting.
  final double deadband;

  double _x = 0;
  double _y = 0;
  double _z = 0;
  bool _hasEstimate = false;
  Offset? _reported;
  ScreenTurn _turn = ScreenTurn.upright;

  /// How the screen is currently taken to be turned.
  ScreenTurn get turn => _turn;

  /// Works out which way round the interface is shown on the device, and
  /// reports up in that frame from then on.
  ///
  /// The sensors measure in the device's own upright frame, so a device held
  /// sideways needs its readings turned to match what is on screen: in
  /// landscape, across and up change places.
  ///
  /// With [followsGravity], for devices such as tablets whose interface is
  /// kept the right way up however they are held, a clearly uppermost edge
  /// decides the turn. That holds even when the interface is shown in a
  /// window of the other shape. While the device lies too flat for gravity
  /// to tell, the shape of the interface decides instead: [isLandscape]
  /// means it is on its side.
  ///
  /// Otherwise the interface only turns when it is shown in landscape, and
  /// gravity picks which of the two ways round.
  void settleTurn({required bool isLandscape, bool followsGravity = false}) {
    if (!_hasEstimate) return;
    final next = (followsGravity ? _uppermostTurn() : null) ??
        (isLandscape ? _sidewaysTurn() : _uprightTurn(followsGravity));
    if (next == _turn) return;
    _turn = next;
    _reported = null;
  }

  /// Takes [turn] as the way the interface is shown, for when the device
  /// itself has said so, and reports up in that frame from then on.
  void turnTo(ScreenTurn turn) {
    if (turn == _turn) return;
    _turn = turn;
    _reported = null;
  }

  /// The turn that would put the top of the interface uppermost, or null
  /// while no edge is clearly the highest or up is not yet known.
  ScreenTurn? get uppermostTurn => _hasEstimate ? _uppermostTurn() : null;

  /// Up projected on the screen as it is currently turned, or null until
  /// the accelerometer has found it.
  Offset? get up => _hasEstimate ? _onScreen() : null;

  /// The turn that puts the top of the interface uppermost, or null while no
  /// edge is clearly the highest.
  ScreenTurn? _uppermostTurn() {
    final sideways = _x.abs();
    final upright = _y.abs();
    if (sideways > _Turn.decisive && sideways > upright + _Turn.margin) {
      return _x > 0 ? ScreenTurn.topToLeft : ScreenTurn.topToRight;
    }
    if (upright > _Turn.decisive && upright > sideways + _Turn.margin) {
      return _y > 0 ? ScreenTurn.upright : ScreenTurn.upsideDown;
    }
    return null;
  }

  /// The turn of an interface shown in portrait: the way it already is when
  /// it may be upside down, and upright otherwise.
  ScreenTurn _uprightTurn(bool mayBeUpsideDown) {
    return mayBeUpsideDown && _turn == ScreenTurn.upsideDown
        ? ScreenTurn.upsideDown
        : ScreenTurn.upright;
  }

  /// Which of the two sideways turns has its top uppermost, keeping the
  /// current one while the device lies too flat to tell.
  ScreenTurn _sidewaysTurn() {
    if (_x > _Turn.decisive) return ScreenTurn.topToLeft;
    if (_x < -_Turn.decisive) return ScreenTurn.topToRight;
    return _turn.isSideways ? _turn : ScreenTurn.topToLeft;
  }

  /// Feeds one accelerometer sample in m/s².
  ///
  /// Returns the up direction projected on the screen when it has moved
  /// beyond the [deadband], otherwise null.
  Offset? addAccelerometer(double x, double y, double z) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    final isSteady = magnitude > _Gravity.steadyMinimum &&
        magnitude < _Gravity.steadyMaximum;
    if (!isSteady) return null;

    final trust = _hasEstimate ? accelerometerTrust : 1.0;
    _hasEstimate = true;
    _set(
      _x + (x / magnitude - _x) * trust,
      _y + (y / magnitude - _y) * trust,
      _z + (z / magnitude - _z) * trust,
    );
    return _report();
  }

  /// Feeds one gyroscope sample in rad/s covering the [elapsed] time.
  ///
  /// Returns the up direction projected on the screen when it has moved
  /// beyond the [deadband], otherwise null.
  Offset? addGyroscope(double x, double y, double z, Duration elapsed) {
    if (!_hasEstimate) return null;
    final seconds = math.min(
      elapsed.inMicroseconds / Duration.microsecondsPerSecond,
      _Gyroscope.longestStepSeconds,
    );
    if (seconds <= 0) return null;

    _set(
      _x + (_y * z - _z * y) * seconds,
      _y + (_z * x - _x * z) * seconds,
      _z + (_x * y - _y * x) * seconds,
    );
    return _report();
  }

  /// Whether an accelerometer sample in m/s² points more than [threshold]
  /// away from the current estimate, which means the device has been moved.
  bool isDisturbedBy(
    double x,
    double y,
    double z, {
    required double threshold,
  }) {
    if (!_hasEstimate) return true;
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (magnitude < _Gravity.degenerateLength) return false;
    final dx = x / magnitude - _x;
    final dy = y / magnitude - _y;
    final dz = z / magnitude - _z;
    return math.sqrt(dx * dx + dy * dy + dz * dz) > threshold;
  }

  /// Forgets the estimate so the next accelerometer sample defines it.
  void reset() {
    _hasEstimate = false;
    _reported = null;
  }

  void _set(double x, double y, double z) {
    final length = math.sqrt(x * x + y * y + z * z);
    if (length < _Gravity.degenerateLength) return;
    _x = x / length;
    _y = y / length;
    _z = z / length;
  }

  /// The device y axis points to the top of an upright screen, the screen y
  /// axis to its bottom; a turned screen swaps and flips the axes to match.
  Offset _onScreen() {
    return switch (_turn) {
      ScreenTurn.upright => Offset(_x, -_y),
      ScreenTurn.upsideDown => Offset(-_x, _y),
      ScreenTurn.topToLeft => Offset(-_y, -_x),
      ScreenTurn.topToRight => Offset(_y, _x),
    };
  }

  Offset? _report() {
    final onScreen = _onScreen();
    final previous = _reported;
    if (previous != null && (onScreen - previous).distance < deadband) {
      return null;
    }
    return _reported = onScreen;
  }
}

/// Which way round the interface is shown on the device.
enum ScreenTurn {
  /// As the device is built: its top edge is the top of the interface.
  upright(0),

  /// Turned half way round.
  upsideDown(math.pi),

  /// On its side with the device's top edge at the left of the interface.
  topToLeft(-math.pi / 2),

  /// On its side with the device's top edge at the right of the interface.
  topToRight(math.pi / 2);

  const ScreenTurn(this.angle);

  /// How far, in radians clockwise on the screen, a direction measured on
  /// the upright device is turned to show it in this interface.
  final double angle;

  /// Whether the interface is shown with the device on its side.
  bool get isSideways => this == topToLeft || this == topToRight;
}

class _Turn {
  /// How far up must lean along an edge before it decides the turn: about
  /// seventeen degrees from flat.
  static const decisive = 0.3;

  /// How much higher one pair of edges must be than the other before the
  /// turn changes, so it does not flicker when held on a corner.
  static const margin = 0.15;
}

class _Gravity {
  static const standard = 9.80665;
  static const steadyMinimum = standard * 0.75;
  static const steadyMaximum = standard * 1.25;
  static const degenerateLength = 1e-6;
}

class _Gyroscope {
  static const longestStepSeconds = 0.1;
}
