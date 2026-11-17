import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/src/light/up_vector_filter.dart';

void main() {
  const gravity = 9.80665;
  const step = Duration(milliseconds: 33);
  const wakeThreshold = 0.03;

  group('UpVectorFilter', () {
    test('a device lying flat has the light straight above the screen', () {
      final filter = UpVectorFilter();

      expect(filter.addAccelerometer(0, 0, gravity), Offset.zero);
    });

    test('a device held upright has the light beyond its top edge', () {
      final filter = UpVectorFilter();

      final light = filter.addAccelerometer(0, gravity, 0)!;

      expect(light.dx, closeTo(0, 1e-9));
      expect(light.dy, closeTo(-1, 1e-9));
    });

    test('ignores rotation until the accelerometer has found up', () {
      final filter = UpVectorFilter();

      expect(filter.addGyroscope(1, 0, 0, step), isNull);
    });

    test('ignores jitter below the deadband', () {
      final filter = UpVectorFilter()..addAccelerometer(0, 0, gravity);

      expect(filter.addAccelerometer(0.02, -0.02, gravity), isNull);
      expect(filter.addGyroscope(0.01, 0.01, 0, step), isNull);
    });

    test('raising the top edge moves the light towards the top edge', () {
      final filter = UpVectorFilter()..addAccelerometer(0, 0, gravity);

      Offset? light;
      for (var sample = 0; sample < 10; sample++) {
        light = filter.addGyroscope(1, 0, 0, step) ?? light;
      }

      expect(light!.dx, closeTo(0, 1e-9));
      expect(light.dy, closeTo(-math.sin(0.33), 0.01));
    });

    test('follows a quarter turn made of gyroscope samples alone', () {
      final filter = UpVectorFilter()..addAccelerometer(0, 0, gravity);

      Offset? light;
      const samples = 100;
      const rate = math.pi / 2 / (samples * 0.01);
      for (var sample = 0; sample < samples; sample++) {
        light = filter.addGyroscope(
              0,
              -rate,
              0,
              const Duration(milliseconds: 10),
            ) ??
            light;
      }

      expect(light!.dx, closeTo(1, 0.02));
    });

    test('distrusts the accelerometer while the device is shaken', () {
      final filter = UpVectorFilter()..addAccelerometer(0, 0, gravity);

      expect(filter.addAccelerometer(20, 0, gravity), isNull);
      expect(filter.addAccelerometer(0.1, 0.1, 0.1), isNull);
    });

    test('the accelerometer corrects gyroscope drift', () {
      final filter = UpVectorFilter()..addAccelerometer(0, 0, gravity);
      for (var sample = 0; sample < 10; sample++) {
        filter.addGyroscope(1, 0, 0, step);
      }

      var light = const Offset(0, -1);
      for (var sample = 0; sample < 200; sample++) {
        light = filter.addAccelerometer(0, 0, gravity) ?? light;
      }

      expect(light.distance, lessThan(0.02));
    });

    test('a still device is not disturbed by its own reading', () {
      final filter = UpVectorFilter()..addAccelerometer(0, 0, gravity);

      expect(
        filter.isDisturbedBy(0, 0, gravity, threshold: wakeThreshold),
        isFalse,
      );
    });

    test('a device picked up and leaned is disturbed', () {
      final filter = UpVectorFilter()..addAccelerometer(0, 0, gravity);
      const lean = 5 * math.pi / 180;

      expect(
        filter.isDisturbedBy(
          gravity * math.sin(lean),
          0,
          gravity * math.cos(lean),
          threshold: wakeThreshold,
        ),
        isTrue,
      );
    });

    test('without an estimate any reading counts as a disturbance', () {
      expect(
        UpVectorFilter().isDisturbedBy(0, 0, gravity, threshold: wakeThreshold),
        isTrue,
      );
    });

    test('a landscape screen with its top at the left turns the light', () {
      final filter = UpVectorFilter()
        ..addAccelerometer(gravity, 0, 0)
        ..settleTurn(isLandscape: true);

      final light = filter.addAccelerometer(gravity, 0, 0)!;

      expect(filter.turn, ScreenTurn.topToLeft);
      expect(light.dx, closeTo(0, 1e-9));
      expect(light.dy, closeTo(-1, 1e-9));
    });

    test('a landscape screen the other way round turns it the other way', () {
      final filter = UpVectorFilter()
        ..addAccelerometer(-gravity, 0, 0)
        ..settleTurn(isLandscape: true);

      final light = filter.addAccelerometer(-gravity, 0, 0)!;

      expect(filter.turn, ScreenTurn.topToRight);
      expect(light.dy, closeTo(-1, 1e-9));
    });

    test('keeps its turn while the device lies too flat to tell', () {
      final filter = UpVectorFilter()
        ..addAccelerometer(-gravity, 0, 0)
        ..settleTurn(isLandscape: true);
      for (var sample = 0; sample < 200; sample++) {
        filter.addAccelerometer(0, 0, gravity);
      }

      filter.settleTurn(isLandscape: true);

      expect(filter.turn, ScreenTurn.topToRight);
    });

    test('a phone in portrait is never turned, however it is held', () {
      final phone = UpVectorFilter()
        ..addAccelerometer(gravity, 0, 0)
        ..settleTurn(isLandscape: false);

      expect(phone.turn, ScreenTurn.upright);
    });

    test('a tablet is turned by how it is held, whatever its window shape', () {
      ScreenTurn turnWhenUpIs(double x, double y) {
        final tablet = UpVectorFilter()
          ..addAccelerometer(x, y, 0)
          ..settleTurn(isLandscape: false, followsGravity: true);
        return tablet.turn;
      }

      expect(turnWhenUpIs(0, gravity), ScreenTurn.upright);
      expect(turnWhenUpIs(0, -gravity), ScreenTurn.upsideDown);
      expect(turnWhenUpIs(gravity, 0), ScreenTurn.topToLeft);
      expect(turnWhenUpIs(-gravity, 0), ScreenTurn.topToRight);
    });

    test('a tablet lying flat is turned by the shape of its interface', () {
      final tablet = UpVectorFilter()
        ..addAccelerometer(0, 0, gravity)
        ..settleTurn(isLandscape: true, followsGravity: true);

      expect(tablet.turn.isSideways, isTrue);

      tablet.settleTurn(isLandscape: false, followsGravity: true);

      expect(tablet.turn, ScreenTurn.upright);
    });

    test('a tablet lying flat in landscape swaps across and up', () {
      final tablet = UpVectorFilter()
        ..addAccelerometer(0, 0, gravity)
        ..settleTurn(isLandscape: true, followsGravity: true);
      const lean = 0.2;

      final light = tablet.addAccelerometer(0, gravity * lean, gravity)!;

      expect(light.dx.abs(), greaterThan(light.dy.abs()));
    });

    test('a tablet held on a corner keeps a sideways turn in landscape', () {
      final tablet = UpVectorFilter()
        ..addAccelerometer(-gravity, 0, 0)
        ..settleTurn(isLandscape: true, followsGravity: true);
      const onCorner = gravity / math.sqrt2;
      for (var sample = 0; sample < 200; sample++) {
        tablet.addAccelerometer(-onCorner, onCorner, 0);
      }

      tablet.settleTurn(isLandscape: true, followsGravity: true);

      expect(tablet.turn, ScreenTurn.topToRight);
    });

    test('light comes from the top in every turn of a tablet', () {
      for (final (x, y) in [
        (0.0, gravity),
        (0.0, -gravity),
        (gravity, 0.0),
        (-gravity, 0.0),
      ]) {
        final tablet = UpVectorFilter();
        final beforeTurning = tablet.addAccelerometer(x, y, 0);
        tablet.settleTurn(isLandscape: false, followsGravity: true);

        final light = tablet.addAccelerometer(x, y, 0) ?? beforeTurning!;

        expect(light.dx, closeTo(0, 1e-9));
        expect(light.dy, closeTo(-1, 1e-9));
      }
    });

    test('follows the turn the device reports, whatever gravity says', () {
      final locked = UpVectorFilter()
        ..addAccelerometer(gravity, 0, 0)
        ..turnTo(ScreenTurn.upright);

      expect(locked.uppermostTurn, ScreenTurn.topToLeft);
      expect(locked.up!.dx, closeTo(1, 1e-9));
      expect(locked.up!.dy, closeTo(0, 1e-9));
    });

    test('reports up in the new frame as soon as it is turned', () {
      final filter = UpVectorFilter()
        ..addAccelerometer(gravity, 0, 0)
        ..turnTo(ScreenTurn.topToLeft);

      expect(filter.up!.dx, closeTo(0, 1e-9));
      expect(filter.up!.dy, closeTo(-1, 1e-9));
    });

    test('knows neither up nor the uppermost turn before any reading', () {
      final filter = UpVectorFilter();

      expect(filter.up, isNull);
      expect(filter.uppermostTurn, isNull);
    });
  });
}
