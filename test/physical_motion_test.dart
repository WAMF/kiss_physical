import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Sample {
  static const velocity = 1000.0;
  static const extent = 400.0;
  static const stops = [0.0, 200.0, 400.0];
  static const farDrag = 100000.0;
  static const nudge = 1.0;
  static const closeTo = 0.01;
  static const moment = Duration(milliseconds: 1);
  static const longHold = Duration(seconds: 2);
}

void main() {
  group('PhysicalMotion', () {
    test('a throw carries about half its speed in distance', () {
      expect(
        PhysicalMotion.throwDistance(_Sample.velocity),
        closeTo(499, _Sample.nudge),
      );
    });

    test('a throw backwards carries backwards as far', () {
      expect(
        PhysicalMotion.throwDistance(-_Sample.velocity),
        -PhysicalMotion.throwDistance(_Sample.velocity),
      );
    });

    test('something let go at rest stays where it is', () {
      expect(PhysicalMotion.restingPlace(120, 0), 120);
    });

    test('a slow release settles on the nearest stop', () {
      expect(PhysicalMotion.stopFor(60, 0, _Sample.stops), 0);
    });

    test('a throw settles on the stop it is thrown towards', () {
      expect(
        PhysicalMotion.stopFor(60, _Sample.velocity, _Sample.stops),
        400,
      );
    });

    test('a small drag past an edge shows as a little less than it is', () {
      final shown = PhysicalMotion.resisted(
        _Sample.nudge,
        extent: _Sample.extent,
      );

      expect(
        shown,
        closeTo(PhysicalMotion.defaultGive, _Sample.closeTo),
      );
    });

    test('however far the drag, what shows stays within the extent', () {
      final shown = PhysicalMotion.resisted(
        _Sample.farDrag,
        extent: _Sample.extent,
      );

      expect(shown, lessThan(_Sample.extent));
    });

    test('a drag the other way resists the other way', () {
      expect(
        PhysicalMotion.resisted(-50, extent: _Sample.extent),
        -PhysicalMotion.resisted(50, extent: _Sample.extent),
      );
    });

    test('a value within its range is left alone', () {
      expect(PhysicalMotion.heldWithin(0.4, lowest: 0, highest: 1), 0.4);
    });

    test('a value past its range gives a little and holds', () {
      final held = PhysicalMotion.heldWithin(1.5, lowest: 0, highest: 1);

      expect(held, greaterThan(1));
      expect(held, lessThan(1.5));
    });
  });

  group('PhysicalFeel', () {
    double bounceOf(PhysicalMaterial material) {
      final spring = PhysicalFeel.of(material).release;
      return spring.damping / (2 * math.sqrt(spring.mass * spring.stiffness));
    }

    PhysicalMaterial made(PhysicalTexture texture) {
      return PhysicalMaterial.gloss.withTexture(texture);
    }

    test('stone settles without springing past rest', () {
      expect(
        bounceOf(made(PhysicalTexture.granite)),
        closeTo(1, _Sample.closeTo),
      );
    });

    test('plastic springs back with more bounce than wood or metal', () {
      final plastic = bounceOf(PhysicalMaterial.gloss);

      expect(plastic, lessThan(bounceOf(made(PhysicalTexture.oak))));
      expect(plastic, lessThan(bounceOf(made(PhysicalTexture.brass))));
    });

    test('heavier substances move as heavier bodies', () {
      double massOf(PhysicalTexture texture) {
        return PhysicalFeel.of(made(texture)).release.mass;
      }

      expect(
        massOf(PhysicalTexture.oak),
        greaterThan(massOf(PhysicalTexture.plastic)),
      );
      expect(
        massOf(PhysicalTexture.brass),
        greaterThan(massOf(PhysicalTexture.oak)),
      );
      expect(
        massOf(PhysicalTexture.carrara),
        greaterThan(massOf(PhysicalTexture.brass)),
      );
    });

    test('the tap follows the weight of the substance', () {
      PhysicalHaptic tapOf(PhysicalTexture texture) {
        return PhysicalFeel.of(made(texture)).haptic;
      }

      expect(tapOf(PhysicalTexture.none), PhysicalHaptic.light);
      expect(tapOf(PhysicalTexture.walnut), PhysicalHaptic.medium);
      expect(tapOf(PhysicalTexture.stainlessSteel), PhysicalHaptic.medium);
      expect(tapOf(PhysicalTexture.granite), PhysicalHaptic.heavy);
    });

    test('a silent feel moves the same and gives no tap', () {
      final feel = PhysicalFeel.of(made(PhysicalTexture.granite));

      expect(feel.silent.haptic, PhysicalHaptic.none);
      expect(feel.silent.release, feel.release);
    });
  });

  group('HoldRepeater', () {
    testWidgets('waits, then repeats faster and faster until let go', (
      tester,
    ) async {
      var repeats = 0;
      final repeater = HoldRepeater(onRepeat: () => repeats++)..start();

      await tester.pump(HoldRepeater.defaultDelay - _Sample.moment);
      expect(repeats, 0);

      await tester.pump(HoldRepeater.defaultSlowest * 2);
      final early = repeats;
      await tester.pump(_Sample.longHold);
      final settled = repeats;
      await tester.pump(HoldRepeater.defaultSlowest * 2);
      final late = repeats - settled;

      expect(early, inInclusiveRange(1, 3));
      expect(late, greaterThan(early));

      repeater.stop();
      await tester.pump(_Sample.longHold);
      expect(repeats, settled + late);
      expect(repeater.repeats, repeats);
      expect(repeater.isRunning, isFalse);
    });

    testWidgets('a hold let go before the wait is over repeats nothing', (
      tester,
    ) async {
      var repeats = 0;
      final repeater = HoldRepeater(onRepeat: () => repeats++)..start();

      await tester.pump(HoldRepeater.defaultDelay ~/ 2);
      repeater.stop();
      await tester.pump(_Sample.longHold);

      expect(repeats, 0);
    });

    testWidgets('a new hold counts its repeats from nothing', (tester) async {
      final repeater = HoldRepeater(onRepeat: () {})..start();
      await tester.pump(_Sample.longHold);
      repeater
        ..stop()
        ..start();

      expect(repeater.repeats, 0);
      repeater.stop();
    });
  });
}
