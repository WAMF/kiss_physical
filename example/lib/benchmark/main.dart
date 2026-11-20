import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Run {
  static const settle = Duration(seconds: 1);
  static const measure = Duration(seconds: 4);
  static const slab = 300.0;
  static const backdrop = Color(0xFF101211);
  static const panel = Color(0xFF1A1D1C);
  static const slabColor = Color(0xFF7C8A86);
  static const orbit = Duration(seconds: 3);
  static const orbitReach = 0.5;
  static const logTag = 'kiss_physical benchmark';
}

/// One thing to time: a name and what fills the screen while it is timed.
class _Scene {
  const _Scene(this.name, this.child);

  _Scene.slab(String name, PhysicalMaterial material)
      : this(name, _Slab(material: material));

  final String name;
  final Widget child;
}

class _Scenes {
  static final _wood = PhysicalMaterial.satin.withTexture(PhysicalTexture.oak);
  static final _steel =
      PhysicalMaterial.satin.withTexture(PhysicalTexture.stainlessSteel);

  static final all = [
    const _Scene('nothing', SizedBox.expand()),
    _Scene.slab('plain satin', PhysicalMaterial.satin),
    _Scene.slab('wood', _wood),
    _Scene.slab('metal', _steel),
    _Scene.slab(
      'stone',
      PhysicalMaterial.satin.withTexture(PhysicalTexture.granite),
    ),
    _Scene.slab(
      'marble',
      PhysicalMaterial.satin.withTexture(PhysicalTexture.carrara),
    ),
    _Scene.slab(
      'plastic',
      PhysicalMaterial.satin.withTexture(PhysicalTexture.plastic),
    ),
    _Scene.slab(
      'neon, no texture',
      PhysicalMaterial.satin.withEffect(const PhysicalEffect.neon()),
    ),
    _Scene.slab('wood in rain', _wood.withEffect(const PhysicalEffect.rain())),
    _Scene.slab(
      'wood on fire',
      _wood.withEffect(const PhysicalEffect.flame()),
    ),
    _Scene.slab(
      'wood on fire in rain',
      _wood
          .withEffect(const PhysicalEffect.flame())
          .withEffect(const PhysicalEffect.rain()),
    ),
    _Scene.slab(
      'liquid in glass',
      PhysicalMaterial.gloss.withVessel(const PhysicalVessel.liquid()),
    ),
    _Scene.slab(
      'overgrown wood',
      _wood.withDecals(
        const PhysicalDecals(moss: 0.45, grass: 0.5, flowers: 0.8),
      ),
    ),
    const _Scene(
      'pegboard, full screen',
      PhysicalPegboard(color: _Run.panel, child: SizedBox.expand()),
    ),
    const _Scene(
      'pegboard with a satin card',
      PhysicalPegboard(
        color: _Run.panel,
        child: Center(child: _Slab(material: PhysicalMaterial.satin)),
      ),
    ),
  ];
}

/// Times each scene in turn on the device it runs on and prints how many
/// frames a second it reached and how long they took. Run it in profile
/// mode: `flutter run --profile -t lib/benchmark/main.dart`.
///
/// Frames a second is the figure to compare: on a device that waits for the
/// display, raster time includes that wait.
void main() {
  runApp(const _Benchmark());
}

class _Benchmark extends StatefulWidget {
  const _Benchmark();

  @override
  State<_Benchmark> createState() => _BenchmarkState();
}

class _BenchmarkState extends State<_Benchmark>
    with SingleTickerProviderStateMixin {
  final _light = ValueNotifier(Offset.zero);
  final _timings = <FrameTiming>[];
  late final Ticker _ticker = createTicker(_moveLight);
  int _index = 0;
  bool _isMeasuring = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_collect);
    _ticker.start();
    _runAll();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_collect);
    _ticker.dispose();
    _light.dispose();
    super.dispose();
  }

  void _moveLight(Duration elapsed) {
    final angle =
        2 * math.pi * elapsed.inMicroseconds / _Run.orbit.inMicroseconds;
    _light.value = Offset(math.cos(angle), math.sin(angle)) * _Run.orbitReach;
  }

  void _collect(List<FrameTiming> timings) {
    if (_isMeasuring) _timings.addAll(timings);
  }

  Future<void> _runAll() async {
    await PhysicalShader.precacheAll();
    for (var index = 0; index < _Scenes.all.length; index++) {
      setState(() => _index = index);
      await Future<void>.delayed(_Run.settle);
      _timings.clear();
      _isMeasuring = true;
      await Future<void>.delayed(_Run.measure);
      _isMeasuring = false;
      await Future<void>.delayed(_Run.settle);
      debugPrint(_Report(_Scenes.all[index].name, List.of(_timings)).line);
    }
    debugPrint('${_Run.logTag}: done');
  }

  @override
  Widget build(BuildContext context) {
    final scene = _Scenes.all[_index];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: _Run.backdrop,
        child: PhysicalLight(
          direction: _light,
          child: KeyedSubtree(key: ValueKey(scene.name), child: scene.child),
        ),
      ),
    );
  }
}

class _Slab extends StatelessWidget {
  const _Slab({required this.material});

  final PhysicalMaterial material;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PhysicalCard(
        width: _Run.slab,
        height: _Run.slab,
        color: _Run.slabColor,
        material: material,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Report {
  _Report(this.name, this.timings);

  final String name;
  final List<FrameTiming> timings;

  String get line {
    if (timings.isEmpty) return '${_Run.logTag}: $name | no frames';
    final raster = _sorted((timing) => timing.rasterDuration);
    final build = _sorted((timing) => timing.buildDuration);
    final perSecond = timings.length / _Run.measure.inSeconds;
    return '${_Run.logTag}: $name | '
        '${perSecond.toStringAsFixed(0)} frames a second | '
        'raster ${_spread(raster)} | build ${_spread(build)}';
  }

  List<Duration> _sorted(Duration Function(FrameTiming) pick) {
    return timings.map(pick).toList()..sort();
  }

  String _spread(List<Duration> sorted) {
    return 'median ${_ms(_at(sorted, 0.5))} p90 ${_ms(_at(sorted, 0.9))} '
        'worst ${_ms(sorted.last)}';
  }

  Duration _at(List<Duration> sorted, double share) {
    return sorted[((sorted.length - 1) * share).round()];
  }

  String _ms(Duration duration) {
    return '${(duration.inMicroseconds / 1000).toStringAsFixed(1)}ms';
  }
}
