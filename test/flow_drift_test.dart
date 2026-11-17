import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/src/surface/flow_drift.dart';

class _Fixture {
  static const frame = 1 / 60;
  static const down = Offset(0, 1);
  static const leftwards = Offset(-1, 0);
  static const flat = Offset.zero;
  static const tolerance = 1e-6;
}

void _run(FlowDrift drift, Offset gravity, {required int frames}) {
  for (var frame = 0; frame < frames; frame++) {
    drift.advance(_Fixture.frame, gravity);
  }
}

void main() {
  test('a fire streams steadily along the way gravity pulls', () {
    final drift = FlowDrift();

    _run(drift, _Fixture.down, frames: 60);

    expect(drift.down, _Fixture.down);
    expect(drift.travelled.dy, closeTo(1, _Fixture.tolerance));
  });

  test('turning gravity never hurries the fire', () {
    final drift = FlowDrift();
    _run(drift, _Fixture.down, frames: 600);

    for (var frame = 0; frame < 120; frame++) {
      final before = drift.travelled;
      drift.advance(_Fixture.frame, _Fixture.leftwards);
      final moved = (drift.travelled - before).distance;

      expect(moved, closeTo(_Fixture.frame, _Fixture.tolerance));
    }
  });

  test('the fire eases round to a new gravity', () {
    final drift = FlowDrift();
    _run(drift, _Fixture.down, frames: 60);

    drift.advance(_Fixture.frame, _Fixture.leftwards);
    expect(drift.down.dy, greaterThan(0.9));

    _run(drift, _Fixture.leftwards, frames: 240);
    expect(drift.down.dx, closeTo(-1, 0.01));
  });

  test('a fire keeps its direction while the device lies flat', () {
    final drift = FlowDrift();
    _run(drift, _Fixture.leftwards, frames: 60);

    _run(drift, _Fixture.flat, frames: 60);

    expect(drift.down.dx, closeTo(-1, _Fixture.tolerance));
  });

  test('a fire on a screen stood on edge rises to its full height', () {
    final drift = FlowDrift();

    _run(drift, _Fixture.down, frames: 60);

    expect(drift.rise, closeTo(1, _Fixture.tolerance));
  });

  test('a fire on a screen lying flat rises only a little across it', () {
    final standing = FlowDrift();
    final lying = FlowDrift();

    _run(standing, _Fixture.down, frames: 60);
    _run(lying, _Fixture.flat, frames: 60);

    expect(lying.rise, greaterThan(0));
    expect(lying.rise, lessThan(standing.rise / 2));
  });

  test('the more a screen leans back, the lower its fire', () {
    double riseWhenPulledBy(double pull) {
      final drift = FlowDrift();
      _run(drift, _Fixture.down * pull, frames: 60);
      return drift.rise;
    }

    expect(riseWhenPulledBy(0.5), lessThan(riseWhenPulledBy(0.9)));
    expect(riseWhenPulledBy(0.1), lessThan(riseWhenPulledBy(0.5)));
  });

  test('a fire sinks gradually as its screen is laid flat', () {
    final drift = FlowDrift();
    _run(drift, _Fixture.down, frames: 60);
    final atFirst = drift.rise;

    drift.advance(_Fixture.frame, _Fixture.flat);

    expect(drift.rise, lessThan(atFirst));
    expect(drift.rise, greaterThan(atFirst / 2));
  });

  test('the lean that steadies a flat fire does not raise it', () {
    final bare = FlowDrift();
    final steadied = FlowDrift();

    bare.advance(_Fixture.frame, _Fixture.flat);
    steadied.advance(
      _Fixture.frame,
      _Fixture.flat,
      whenFlat: _Fixture.down / 10,
    );

    expect(steadied.rise, bare.rise);
    expect(steadied.down, _Fixture.down);
  });
}
