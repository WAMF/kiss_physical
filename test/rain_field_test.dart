import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/src/surface/rain_field.dart';

class _Fixture {
  static const frame = 1 / 60;
  static const surface = Size(400, 400);
  static const middle = Offset(200, 200);
  static const down = Offset(0, 1);
  static const rightwards = Offset(1, 0);
  static const heavy = 9.0;
  static const light = 3.0;
  static const seed = 7;
  static const gripping = 0.1;
}

RainField _field() => RainField(random: math.Random(_Fixture.seed));

void _run(
  RainField field,
  Offset gravity, {
  required int frames,
  double rain = 0,
}) {
  for (var frame = 0; frame < frames; frame++) {
    field.advance(
      _Fixture.frame,
      size: _Fixture.surface,
      gravity: gravity,
      rain: rain,
    );
  }
}

void main() {
  test('drops land while it rains and none land when it is dry', () {
    final raining = _field();
    final dry = _field();

    _run(raining, _Fixture.down, frames: 120, rain: 1);
    _run(dry, _Fixture.down, frames: 120);

    expect(raining.drops, isNotEmpty);
    expect(dry.drops, isEmpty);
  });

  test('a heavy drop runs down and a light one stays where it fell', () {
    final field = _field();
    final heavy = field.land(_Fixture.middle, _Fixture.heavy);
    final light = field.land(const Offset(50, 50), _Fixture.light);

    _run(field, _Fixture.down, frames: 60);

    expect(heavy.position.dy, greaterThan(_Fixture.middle.dy + 10));
    expect(light.position, const Offset(50, 50));
  });

  test('turning gravity bends a running drop from where it already is', () {
    final field = _field();
    final drop = field.land(_Fixture.middle, _Fixture.heavy);
    _run(field, _Fixture.down, frames: 60);
    final atTurn = drop.position;

    _run(field, _Fixture.rightwards, frames: 2);
    final justAfter = drop.velocity;
    _run(field, _Fixture.rightwards, frames: 90);

    expect((drop.position - atTurn).dy, greaterThan(0));
    expect(justAfter.dy.abs(), greaterThan(justAfter.dx.abs()));
    expect(drop.velocity.dx, greaterThan(drop.velocity.dy.abs()));
    expect(drop.position.dx, greaterThan(atTurn.dx + 10));
  });

  test('on a surface lying flat nothing runs', () {
    final field = _field();
    final drop = field.land(_Fixture.middle, _Fixture.heavy);

    _run(field, Offset.zero, frames: 60);

    expect(drop.position, _Fixture.middle);
  });

  test('a rough finish holds a drop that a smooth one lets run', () {
    final field = _field();
    final drop = field.land(_Fixture.middle, _Fixture.heavy);

    for (var frame = 0; frame < 60; frame++) {
      field.advance(
        _Fixture.frame,
        size: _Fixture.surface,
        gravity: _Fixture.down,
        rain: 0,
        slip: _Fixture.gripping,
      );
    }

    expect(drop.position, _Fixture.middle);
  });

  test('a drop runs further down a slick body than one that grips', () {
    double fallOn(double slip) {
      final field = _field();
      final drop = field.land(_Fixture.middle, _Fixture.heavy);
      for (var frame = 0; frame < 30; frame++) {
        field.advance(
          _Fixture.frame,
          size: _Fixture.surface,
          gravity: _Fixture.down,
          rain: 0,
          slip: slip,
        );
      }
      return drop.position.dy - _Fixture.middle.dy;
    }

    expect(fallOn(0.5), greaterThan(0));
    expect(fallOn(1), greaterThan(fallOn(0.5)));
  });

  test('a running drop draws its wake out behind it', () {
    final field = _field();
    final drop = field.land(_Fixture.middle, _Fixture.heavy);

    _run(field, _Fixture.down, frames: 45);

    final rear = drop.wake.last;
    expect(rear.dy, lessThan(drop.position.dy));
    expect((rear - drop.position).distance, greaterThan(drop.radius));
  });

  test('a drop that comes to rest gathers its wake back in', () {
    final field = _field();
    final drop = field.land(_Fixture.middle, _Fixture.heavy);
    _run(field, _Fixture.down, frames: 45);

    _run(field, Offset.zero, frames: 240);

    expect(
      (drop.wake.last - drop.position).distance,
      lessThan(drop.radius),
    );
  });

  test('a running drop sweeps up a drop in its way', () {
    final field = _field()
      ..land(_Fixture.middle, _Fixture.heavy)
      ..land(_Fixture.middle + const Offset(0, 12), _Fixture.light);

    _run(field, _Fixture.down, frames: 90);

    expect(field.drops, hasLength(1));
  });
}
