import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/light/light_pacing.dart';
import 'package:kiss_physical/src/light/screen_turn_reader.dart';
import 'package:kiss_physical/src/light/screen_turn_transition.dart';
import 'package:kiss_physical/src/light/sky_light.dart';
import 'package:kiss_physical/src/light/up_vector_filter.dart';
import 'package:kiss_physical/src/light/viewing_sway.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Shares where the light is with every physical surface below it.
///
/// The light is given as the screen-plane part of the unit vector pointing
/// at it: `Offset.zero` is a light straight above the screen, negative y
/// puts it beyond the top edge and negative x beyond the left edge.
class PhysicalLight extends InheritedWidget {
  /// Creates a light at [direction] for the surfaces in [child].
  const PhysicalLight({
    required this.direction,
    required super.child,
    this.tone = neutralTone,
    this.sway = noSway,
    this.gravity = upright,
    super.key,
  });

  /// Creates a light that stays where [direction] puts it, in white unless
  /// a [tone] is given. Suited to previews, screenshots and devices that
  /// cannot feel how they are held.
  ///
  /// [direction] is the screen-plane part of the unit vector pointing at
  /// the light: `Offset.zero` is straight above the screen, negative y is
  /// beyond its top edge and negative x beyond its left edge.
  PhysicalLight.fixed({
    required Widget child,
    Offset? direction,
    LightTone tone = LightTone.neutral,
    Key? key,
  }) : this(
          direction: AlwaysStoppedAnimation(direction ?? still.value),
          tone: AlwaysStoppedAnimation(tone),
          key: key,
          child: child,
        );

  /// A fixed light above the top-left of the screen, as for a handset held
  /// at a reading angle.
  static const ValueListenable<Offset> still = _StillLight();

  /// White light, for surfaces outside any [PhysicalLight] or under one
  /// that sets no colour.
  static const ValueListenable<LightTone> neutralTone = _NeutralTone();

  /// No sway, for layers outside any [PhysicalLight] or under one that does
  /// not follow the device.
  static const ValueListenable<Offset> noSway = _NoSway();

  /// Gravity for a screen stood upright, for bodies outside any
  /// [PhysicalLight] or under one that does not follow the device.
  static const ValueListenable<Offset> upright = _UprightGravity();

  /// Where the light is: the screen-plane part of the unit vector pointing
  /// at it.
  final ValueListenable<Offset> direction;

  /// Which way the real world's down lies on the screen: its direction is
  /// where things fall, and its length runs from 0 with the screen lying
  /// flat to 1 with it stood upright. Flames, rain and liquids that are not
  /// given a gravity of their own follow it.
  final ValueListenable<Offset> gravity;

  /// The gravity of the nearest [PhysicalLight], or [upright] without one.
  static ValueListenable<Offset> gravityOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PhysicalLight>()
            ?.gravity ??
        upright;
  }

  /// How far the viewer is off the usual line of sight as the device is
  /// tilted: the direction, on the screen, of the side now nearer the viewer.
  /// Layers beneath the screen shift along it.
  final ValueListenable<Offset> sway;

  /// The sway of the nearest [PhysicalLight], or [noSway] without one.
  static ValueListenable<Offset> swayOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PhysicalLight>()?.sway ??
        noSway;
  }

  /// The colours of the light.
  final ValueListenable<LightTone> tone;

  /// The colours of the nearest [PhysicalLight], or [neutralTone] without
  /// one.
  static ValueListenable<LightTone> toneOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PhysicalLight>()?.tone ??
        neutralTone;
  }

  /// The light of the nearest [PhysicalLight], or [still] without one.
  static ValueListenable<Offset> of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PhysicalLight>()
            ?.direction ??
        still;
  }

  @override
  bool updateShouldNotify(PhysicalLight oldWidget) =>
      direction != oldWidget.direction ||
      tone != oldWidget.tone ||
      sway != oldWidget.sway ||
      gravity != oldWidget.gravity;
}

/// Hangs the [PhysicalLight] for its subtree overhead in the real world, so
/// that it stays put as the device turns beneath it.
///
/// The gyroscope and accelerometer are sampled at a modest rate, only on
/// handheld devices, only while the app is in the foreground, and not at all
/// when the user asked for reduced motion. Surfaces repaint only when the
/// light has visibly moved, and a device left still is watched with only an
/// occasional accelerometer sample, so it costs no frames and little CPU.
///
/// With a [sky], the light also leans and takes its colours as the sun or
/// moon does there.
class WorldLight extends StatefulWidget {
  /// Creates a light that stays put in the world for the surfaces in [child].
  const WorldLight({required this.child, this.sky, super.key});

  /// The subtree the light falls on.
  final Widget child;

  /// Where the sun or moon stands; without one the light is white and
  /// straight overhead.
  final ValueListenable<SkyLight>? sky;

  @override
  State<WorldLight> createState() => _WorldLightState();
}

class _WorldLightState extends State<WorldLight>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _direction = ValueNotifier<Offset>(PhysicalLight.still.value);
  final _tone = ValueNotifier<LightTone>(LightTone.neutral);
  final _sway = ValueNotifier<Offset>(Offset.zero);
  final _gravity = ValueNotifier<Offset>(PhysicalLight.upright.value);
  final _viewingSway = ViewingSway();
  Offset _overhead = PhysicalLight.still.value;
  Offset _shownOverhead = PhysicalLight.still.value;
  final _filter = UpVectorFilter();
  final _turnReader = const ScreenTurnReader();
  final _turnTransition = ScreenTurnTransition();
  final _sinceTurn = Stopwatch();
  final _sinceTurnRead = Stopwatch()..start();
  late final Ticker _turnTicker;
  bool _knowsTurn = false;
  bool _isReadingTurn = false;
  bool _turnIsStale = false;
  StreamSubscription<AccelerometerEvent>? _accelerometer;
  StreamSubscription<GyroscopeEvent>? _gyroscope;
  DateTime? _lastRotation;
  bool _reducedMotion = false;
  bool _isResting = false;
  bool _isLandscape = false;
  bool _isTablet = false;
  bool _isTracking = false;
  int _sensorRequest = 0;
  Offset? _pendingOverhead;
  final _pacing = LightPacing();
  final _sinceMovement = Stopwatch()..start();
  final _sinceShown = Stopwatch()..start();
  Timer? _lightTimer;
  Timer? _restTimer;

  static bool get _hasMotionSensors =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _turnTicker = createTicker(_onTurnTick);
    widget.sky?.addListener(_onSkyChanged);
    _onSkyChanged();
  }

  @override
  void didUpdateWidget(WorldLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sky == widget.sky) return;
    oldWidget.sky?.removeListener(_onSkyChanged);
    widget.sky?.addListener(_onSkyChanged);
    _onSkyChanged();
  }

  void _onSkyChanged() {
    final sky = widget.sky?.value ?? SkyLight.neutral;
    _tone.value = sky.tone;
    _direction.value = _shownOverhead + sky.lean;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _readScreen();
    _syncSensors(WidgetsBinding.instance.lifecycleState);
  }

  @override
  void didChangeMetrics() {
    _readScreen();
    unawaited(_readTurn());
  }

  /// Notes which way round the interface is shown and whether the device is
  /// a tablet.
  ///
  /// The whole view is measured, not the space this widget has been given:
  /// the sensors report against the device, so it is the device's screen
  /// that says how to turn them, however small a pane the light sits in.
  void _readScreen() {
    final view = View.maybeOf(context);
    final screen = view == null
        ? MediaQuery.maybeSizeOf(context) ?? Size.zero
        : view.physicalSize / view.devicePixelRatio;
    _isLandscape = screen.width > screen.height;
    _isTablet = screen.shortestSide >= _Sampling.tabletShortestSide;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncSensors(state);
  }

  void _syncSensors(AppLifecycleState? state) {
    final inForeground = state == null || state == AppLifecycleState.resumed;
    if (_hasMotionSensors && inForeground && !_reducedMotion) {
      if (_isTracking) return;
      _isTracking = true;
      unawaited(_readTurn());
      unawaited(_follow());
    } else {
      _stop();
    }
  }

  /// Tracks the device closely with both sensors.
  Future<void> _follow() async {
    if (!await _releaseSensors()) return;
    _isResting = false;
    _accelerometer = accelerometerEventStream(
      samplingPeriod: _Sampling.period,
    ).listen(_onAcceleration, onError: _onSensorUnavailable);
    _gyroscope = gyroscopeEventStream(
      samplingPeriod: _Sampling.period,
    ).listen(_onRotation, onError: _onGyroscopeUnavailable);
    _restartRestTimer();
  }

  /// Watches a still device with occasional accelerometer samples only.
  Future<void> _rest() async {
    if (!await _releaseSensors()) return;
    _isResting = true;
    _accelerometer = accelerometerEventStream(
      samplingPeriod: _Sampling.restingPeriod,
    ).listen(_onRestingAcceleration, onError: _onSensorUnavailable);
  }

  /// Cancels the current subscriptions and waits for the platform to let go
  /// of the sensors, since subscribing again before then leaves them off.
  ///
  /// Returns whether the caller is still the latest to ask for the sensors.
  Future<bool> _releaseSensors() async {
    final request = ++_sensorRequest;
    await _cancelSensors();
    return request == _sensorRequest && _isTracking && mounted;
  }

  void _restartRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer(_Sampling.restAfter, () => unawaited(_rest()));
  }

  void _onAcceleration(AccelerometerEvent event) {
    if (_knowsTurn) {
      _recheckTurn();
    } else {
      _guessTurn();
    }
    _publish(_filter.addAccelerometer(event.x, event.y, event.z));
  }

  /// Asks the device which way round the interface is shown and follows
  /// its answer. Asked again while an answer is awaited, it asks once more
  /// afterwards so the last answer is never out of date.
  Future<void> _readTurn() async {
    if (!_hasMotionSensors) return;
    if (_isReadingTurn) {
      _turnIsStale = true;
      return;
    }
    _isReadingTurn = true;
    ScreenTurn? turn;
    do {
      _turnIsStale = false;
      turn = await _turnReader.read();
    } while (_turnIsStale && mounted);
    _isReadingTurn = false;
    _sinceTurnRead
      ..reset()
      ..start();
    if (!mounted || !_isTracking || turn == null) return;

    final swings = _knowsTurn;
    _knowsTurn = true;
    _turnTo(turn, swings: swings);
  }

  /// Asks again once gravity says the interface ought to be shown another
  /// way round, since a half turn changes nothing else that could be seen.
  void _recheckTurn() {
    final uppermost = _filter.uppermostTurn;
    if (uppermost == null || uppermost == _filter.turn) return;
    if (_sinceTurnRead.elapsed < _Sampling.turnRecheck) return;
    unawaited(_readTurn());
  }

  /// Works the turn out from gravity and the shape of the screen, for
  /// devices that cannot say which way round they show the interface.
  void _guessTurn() {
    final turnBefore = _filter.turn;
    _filter.settleTurn(
      isLandscape: _isLandscape,
      followsGravity: _isTablet,
    );
    if (_filter.turn != turnBefore) _viewingSway.reset();
  }

  /// Follows the interface to [turn]. When it [swings] there, the light
  /// and gravity are held true to the world for as long as the swing lasts.
  void _turnTo(ScreenTurn turn, {required bool swings}) {
    final from = _filter.turn;
    if (from == turn) return;
    _filter.turnTo(turn);
    _viewingSway.reset();
    if (swings) {
      _turnTransition.begin(
        from,
        turn,
        interruptedAfter: _turnTicker.isActive ? _sinceTurn.elapsed : null,
      );
      _sinceTurn
        ..reset()
        ..start();
      if (!_turnTicker.isActive) unawaited(_turnTicker.start());
    } else {
      _turnTransition.finish();
    }
    _pendingOverhead = null;
    _showLight(_filter.up ?? _overhead);
  }

  void _onTurnTick(Duration _) {
    if (_turnTransition.isSettledAfter(_sinceTurn.elapsed)) {
      _turnTicker.stop();
      _turnTransition.finish();
      _viewingSway.reset();
    }
    _showLight(_overhead);
  }

  void _onRestingAcceleration(AccelerometerEvent event) {
    final wasMoved = _filter.isDisturbedBy(
      event.x,
      event.y,
      event.z,
      threshold: _Sampling.wakeThreshold,
    );
    if (!wasMoved || !_isResting) return;
    _isResting = false;
    _filter.reset();
    _publish(_filter.addAccelerometer(event.x, event.y, event.z));
    unawaited(_readTurn());
    unawaited(_follow());
  }

  void _onRotation(GyroscopeEvent event) {
    final previous = _lastRotation;
    _lastRotation = event.timestamp;
    if (previous == null) return;
    _publish(
      _filter.addGyroscope(
        event.x,
        event.y,
        event.z,
        event.timestamp.difference(previous),
      ),
    );
  }

  /// Takes a new light position and shows it as soon as the pace allows:
  /// at once while the device is swung about, less and less often as the
  /// movement dies away, yet always ending where the device does.
  void _publish(Offset? overhead) {
    if (overhead == null) return;
    final wait = _pacing.follow(
      (overhead - (_pendingOverhead ?? _overhead)).distance,
      _sinceMovement.elapsed,
    );
    _sinceMovement
      ..reset()
      ..start();
    _pendingOverhead = overhead;
    _restartRestTimer();

    final remaining = wait - _sinceShown.elapsed;
    if (remaining <= Duration.zero) {
      _lightTimer?.cancel();
      _showPendingLight();
    } else {
      _lightTimer ??= Timer(remaining, _showPendingLight);
    }
  }

  void _showPendingLight() {
    _lightTimer = null;
    final overhead = _pendingOverhead;
    if (overhead == null) return;
    _pendingOverhead = null;
    _sinceShown
      ..reset()
      ..start();
    _showLight(overhead);
  }

  /// Shows the light at [overhead], given in the current turn of the
  /// interface, held back by whatever the interface has still to swing.
  void _showLight(Offset overhead) {
    _overhead = overhead;
    final held = _turnTransition.hold(overhead, _sinceTurn.elapsed);
    _shownOverhead = held;
    _direction.value = held + (widget.sky?.value ?? SkyLight.neutral).lean;
    _sway.value =
        _turnTicker.isActive ? Offset.zero : _viewingSway.follow(overhead);
    _gravity.value = -held;
  }

  void _onGyroscopeUnavailable(Object _) {
    unawaited(_gyroscope?.cancel());
    _gyroscope = null;
  }

  void _onSensorUnavailable(Object _) => _stop();

  Future<void> _cancelSensors() async {
    final cancellations = [_accelerometer?.cancel(), _gyroscope?.cancel()];
    _accelerometer = null;
    _gyroscope = null;
    _lastRotation = null;
    await Future.wait(cancellations.nonNulls);
  }

  void _stop() {
    _isTracking = false;
    _sensorRequest++;
    unawaited(_cancelSensors());
    _restTimer?.cancel();
    _lightTimer?.cancel();
    _restTimer = null;
    _lightTimer = null;
    _pendingOverhead = null;
    _isResting = false;
    _knowsTurn = false;
    _turnTicker.stop();
    _turnTransition.finish();
    _filter.reset();
    _viewingSway.reset();
    _pacing.reset();
    _sway.value = Offset.zero;
    _gravity.value = PhysicalLight.upright.value;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_accelerometer?.cancel());
    unawaited(_gyroscope?.cancel());
    _restTimer?.cancel();
    _lightTimer?.cancel();
    _turnTicker.dispose();
    widget.sky?.removeListener(_onSkyChanged);
    _direction.dispose();
    _tone.dispose();
    _sway.dispose();
    _gravity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PhysicalLight(
      direction: _direction,
      tone: _tone,
      sway: _sway,
      gravity: _gravity,
      child: widget.child,
    );
  }
}

class _Sampling {
  static const period = Duration(milliseconds: 33);

  /// How often a resting device is checked for being picked up.
  static const restingPeriod = Duration(milliseconds: 100);

  /// How soon the device may be asked again which way round it shows the
  /// interface while gravity disagrees with its last answer.
  static const turnRecheck = Duration(milliseconds: 100);

  /// How long the light must stay put before the device counts as resting.
  static const restAfter = Duration(seconds: 3);

  /// Shortest side, in logical pixels, from which a device counts as a
  /// tablet, whose interface is kept the right way up however it is held.
  static const tabletShortestSide = 600.0;

  /// How far a resting device must lean, as a share of a right angle's sine,
  /// before it counts as moved.
  static const wakeThreshold = 0.03;
}

class _NoSway implements ValueListenable<Offset> {
  const _NoSway();

  @override
  Offset get value => Offset.zero;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _StillLight implements ValueListenable<Offset> {
  const _StillLight();

  @override
  Offset get value => const Offset(-0.25, -0.45);

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _UprightGravity implements ValueListenable<Offset> {
  const _UprightGravity();

  @override
  Offset get value => const Offset(0, 1);

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _NeutralTone implements ValueListenable<LightTone> {
  const _NeutralTone();

  @override
  LightTone get value => LightTone.neutral;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
