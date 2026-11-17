import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/src/surface/liquid_slosh.dart';

class _Fixture {
  static const frame = 1 / 60;
  static const down = Offset(0, 1);
  static const rightwards = Offset(1, 0);
  static const lyingFlat = Offset.zero;
  static const tolerance = 0.02;
  static const framesToSettle = 600;
}

void _run(LiquidSlosh slosh, Offset gravity, {required int frames}) {
  for (var frame = 0; frame < frames; frame++) {
    slosh.advance(_Fixture.frame, gravity);
  }
}

void main() {
  test('a liquid at rest faces away from gravity', () {
    final slosh = LiquidSlosh();

    _run(slosh, _Fixture.down, frames: _Fixture.framesToSettle);

    expect(slosh.surfaceUp.dx, closeTo(0, _Fixture.tolerance));
    expect(slosh.surfaceUp.dy, closeTo(-1, _Fixture.tolerance));
    expect(slosh.agitation, closeTo(0, _Fixture.tolerance));
  });

  test('when gravity turns the surface swings past level before settling', () {
    final slosh = LiquidSlosh();
    _run(slosh, _Fixture.down, frames: 1);

    var furthestPastLevel = 0.0;
    for (var frame = 0; frame < _Fixture.framesToSettle; frame++) {
      slosh.advance(_Fixture.frame, _Fixture.rightwards);
      if (slosh.surfaceUp.dy > furthestPastLevel) {
        furthestPastLevel = slosh.surfaceUp.dy;
      }
    }

    expect(furthestPastLevel, greaterThan(_Fixture.tolerance));
    expect(slosh.surfaceUp.dx, closeTo(-1, _Fixture.tolerance));
    expect(slosh.surfaceUp.dy, closeTo(0, _Fixture.tolerance));
  });

  test('swinging stirs the liquid up and resting calms it', () {
    final slosh = LiquidSlosh();
    _run(slosh, _Fixture.down, frames: 1);

    _run(slosh, _Fixture.rightwards, frames: 20);
    final stirred = slosh.agitation;
    _run(slosh, _Fixture.rightwards, frames: _Fixture.framesToSettle);

    expect(stirred, greaterThan(0.2));
    expect(slosh.agitation, lessThan(stirred / 10));
  });

  test('a head of foam outlasts the shaking that raised it', () {
    final slosh = LiquidSlosh();
    _run(slosh, _Fixture.down, frames: 1);

    _run(slosh, _Fixture.rightwards, frames: 60);
    final whipped = slosh.foam;
    _run(slosh, _Fixture.rightwards, frames: 240);

    expect(whipped, greaterThan(0.2));
    expect(slosh.agitation, lessThan(0.05));
    expect(slosh.foam, greaterThan(whipped / 4));
  });

  test('a vessel lying flat keeps its surface where it was', () {
    final slosh = LiquidSlosh();
    _run(slosh, _Fixture.down, frames: _Fixture.framesToSettle);
    final before = slosh.surfaceUp;

    _run(slosh, _Fixture.lyingFlat, frames: 60);

    expect(slosh.surfaceUp, before);
  });
}
