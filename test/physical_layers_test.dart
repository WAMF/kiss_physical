import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

Widget _surface(PhysicalMaterial material) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox.square(
        dimension: 100,
        child: PhysicalSurface(
          color: Colors.grey,
          material: material,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

void main() {
  group('PhysicalDecals', () {
    test('showing the hint map counts as something to draw', () {
      expect(PhysicalDecals.none.isEmpty, isTrue);
      expect(const PhysicalDecals(showHints: true).isEmpty, isFalse);
    });
  });

  group('PhysicalEffect', () {
    test('a steady neon tube is still and a flickering one moves', () {
      expect(const PhysicalEffect.neon().isAnimated, isFalse);
      expect(const PhysicalEffect.neon(flicker: 0.5).isAnimated, isTrue);
    });

    test('growth never moves a body; rain, fire and liquid do', () {
      const overgrown = PhysicalDecals(moss: 1, grass: 1, flowers: 1, dew: 1);
      final grown = PhysicalMaterial.satin.withDecals(overgrown);

      expect(grown.isAnimated, isFalse);
      expect(grown.withEffect(const PhysicalEffect.rain()).isAnimated, isTrue);
      expect(grown.withEffect(const PhysicalEffect.flame()).isAnimated, isTrue);
      expect(
        grown.withVessel(const PhysicalVessel.liquid()).isAnimated,
        isTrue,
      );
      expect(
        grown.withVessel(const PhysicalVessel.glass()).isAnimated,
        isFalse,
      );
    });

    test('a body carries one effect of each kind', () {
      const drizzle = PhysicalEffect.rain(intensity: 0.2);
      const downpour = PhysicalEffect.rain(intensity: 1);
      const fire = PhysicalEffect.flame();
      final material = PhysicalMaterial.satin
          .withEffect(drizzle)
          .withEffect(fire)
          .withEffect(downpour);

      expect(material.effects, hasLength(2));
      expect(material.effectOf(PhysicalEffectKind.rain), downpour);
      expect(material.effectOf(PhysicalEffectKind.flame), fire);
      expect(material.effectOf(PhysicalEffectKind.neon), isNull);
      expect(material.withoutEffects().effects, isEmpty);
    });

    test('glass does not burn', () {
      final oak = PhysicalMaterial.satin.withTexture(PhysicalTexture.oak);

      expect(oak.flammability, greaterThan(0));
      expect(oak.withVessel(const PhysicalVessel.glass()).flammability, 0);
    });

    test('a body paints past its flames, as far as their sparks fly', () {
      const flames = PhysicalEffect.flame(height: 80);
      final burning = PhysicalMaterial.matte.withEffect(flames);

      expect(PhysicalMaterial.matte.paintReach, 0);
      expect(burning.paintReach, greaterThan(flames.height));
      expect(burning.paintReach, flames.reach);
    });
  });

  test('water runs most freely off plastic and least off worn stone', () {
    double slipOn(PhysicalTexture texture) =>
        PhysicalMaterial.satin.withTexture(texture).slip;

    final plastic = slipOn(PhysicalTexture.plastic);
    final oak = slipOn(PhysicalTexture.oak);
    final granite = slipOn(PhysicalTexture.granite);
    final wornGranite = slipOn(PhysicalTexture.granite.imperfect(1));

    expect(plastic, greaterThan(oak));
    expect(oak, greaterThan(granite));
    expect(granite, greaterThan(wornGranite));
    expect(wornGranite, greaterThan(0));
  });

  test('a pressed material keeps what is on it and how it is drawn', () {
    const decals = PhysicalDecals(moss: 0.5);
    const effect = PhysicalEffect.flame();
    const vessel = PhysicalVessel.glass();
    final material = PhysicalMaterial.gloss
        .withDecals(decals)
        .withVessel(vessel)
        .withEffect(effect);

    expect(material.pressed(1).decals, decals);
    expect(material.pressed(1).vessel, vessel);
    expect(material.pressed(1).effects, [effect]);
  });

  testWidgets('a surface in the rain keeps repainting, a dry one rests',
      (tester) async {
    await tester.pumpWidget(_surface(PhysicalMaterial.satin));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(
      _surface(
        PhysicalMaterial.satin.withEffect(const PhysicalEffect.rain()),
      ),
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(_surface(PhysicalMaterial.satin));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
