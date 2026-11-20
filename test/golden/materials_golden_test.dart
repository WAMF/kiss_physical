import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

import 'golden_support.dart';

PhysicalMaterial _of(PhysicalTexture texture) {
  return PhysicalMaterial.satin.withTexture(texture);
}

void main() {
  useTolerantGoldens('test/golden/materials_golden_test.dart');

  testWidgets('finishes', (tester) async {
    await expectSheet(tester, 'finishes', [
      slab(PhysicalMaterial.satin),
      slab(PhysicalMaterial.matte),
      slab(PhysicalMaterial.gloss, borderRadius: PhysicalSurface.stadium),
      slab(PhysicalMaterial.glass),
      slab(
        PhysicalMaterial.bead,
        color: Sheet.accent,
        borderRadius: PhysicalSurface.stadium,
      ),
      slab(PhysicalMaterial.well),
      slab(PhysicalMaterial.socket, borderRadius: PhysicalSurface.stadium),
      slab(PhysicalMaterial.peg, borderRadius: PhysicalSurface.stadium),
      slab(PhysicalMaterial.panel),
      slab(PhysicalMaterial.floatingPanel),
      slab(PhysicalMaterial.gloss.pressed(1), color: Sheet.accent),
      slab(_of(PhysicalTexture.plastic)),
    ]);
  });

  testWidgets('woods', (tester) async {
    await expectSheet(tester, 'woods', [
      for (final wood in PhysicalTexture.woods.values) slab(_of(wood)),
    ]);
  });

  testWidgets('stones', (tester) async {
    await expectSheet(tester, 'stones', [
      for (final stone in PhysicalTexture.stones.values) slab(_of(stone)),
    ]);
  });

  testWidgets('metals', (tester) async {
    await expectSheet(tester, 'metals', [
      for (final metal in PhysicalTexture.metals.values) slab(_of(metal)),
    ]);
  });

  testWidgets('wear', (tester) async {
    await expectSheet(tester, 'wear', [
      slab(_of(PhysicalTexture.oak.aged(0.8))),
      slab(_of(PhysicalTexture.oak.imperfect(0.8))),
      slab(_of(PhysicalTexture.copper.aged(1))),
      slab(_of(PhysicalTexture.copper.dented(0.8))),
      slab(_of(PhysicalTexture.stainlessSteel.scratched())),
      slab(_of(PhysicalTexture.granite.imperfect(0.7))),
      slab(_of(PhysicalTexture.travertine.aged(0.5).dented(0.9))),
      slab(_of(PhysicalTexture.plastic.aged(0.8).scratched())),
      slab(_of(PhysicalTexture.walnut.scaled(2))),
      slab(_of(PhysicalTexture.walnut.faded(0.4))),
      slab(_of(PhysicalTexture.carrara.tinted(Sheet.accent))),
      slab(_of(PhysicalTexture.brass.aged(0.6).scratched())),
    ]);
  });

  testWidgets('growth', (tester) async {
    await expectSheet(tester, 'growth', [
      slab(
        _of(PhysicalTexture.slate).withDecals(const PhysicalDecals(moss: 0.6)),
      ),
      slab(
        _of(PhysicalTexture.granite)
            .withDecals(const PhysicalDecals(grass: 0.7)),
      ),
      slab(
        _of(PhysicalTexture.travertine).withDecals(
          const PhysicalDecals(moss: 0.5, grass: 0.6, flowers: 0.7),
        ),
      ),
      slab(
        _of(PhysicalTexture.copper).withDecals(const PhysicalDecals(dew: 0.7)),
      ),
      slab(
        _of(PhysicalTexture.oak).withDecals(
          const PhysicalDecals(moss: 0.4, dew: 0.5, showHints: true),
        ),
      ),
      slab(
        PhysicalMaterial.satin.withDecals(const PhysicalDecals(moss: 0.8)),
      ),
    ]);
  });

  testWidgets('effects', (tester) async {
    await expectSheet(tester, 'effects', [
      slab(PhysicalMaterial.satin.withEffect(const PhysicalEffect.neon())),
      slab(
        PhysicalMaterial.gloss.withEffect(
          const PhysicalEffect.neon(color: Sheet.accent, tube: 0.6),
        ),
        borderRadius: PhysicalSurface.stadium,
      ),
      slab(
        _of(PhysicalTexture.oak).withEffect(const PhysicalEffect.flame()),
      ),
      slab(
        _of(PhysicalTexture.walnut).withEffect(
          const PhysicalEffect.flame(scorch: 0.8, embers: 0.9),
        ),
      ),
      slab(
        _of(PhysicalTexture.slate).withEffect(const PhysicalEffect.rain()),
      ),
      slab(
        _of(PhysicalTexture.copper)
            .withEffect(const PhysicalEffect.rain(intensity: 0.9))
            .withEffect(const PhysicalEffect.neon(color: Sheet.accent)),
      ),
      slab(
        PhysicalMaterial.satin
            .withEffect(const PhysicalEffect.flame())
            .withEffect(const PhysicalEffect.rain()),
      ),
      slab(
        _of(PhysicalTexture.slate)
            .withDecals(const PhysicalDecals(moss: 0.55))
            .withEffect(const PhysicalEffect.rain(intensity: 0.9)),
      ),
    ]);
  });

  testWidgets('vessels', (tester) async {
    await expectSheet(tester, 'vessels', [
      slab(PhysicalMaterial.gloss.withVessel(const PhysicalVessel.glass())),
      slab(
        PhysicalMaterial.gloss.withVessel(
          const PhysicalVessel.glass(color: Sheet.accent),
        ),
        borderRadius: PhysicalSurface.stadium,
      ),
      slab(
        PhysicalMaterial.gloss.withVessel(
          const PhysicalVessel.liquid(gravity: Offset(0, 1)),
        ),
      ),
      slab(
        PhysicalMaterial.bead.withVessel(
          const PhysicalVessel.liquid(
            color: Sheet.accent,
            fill: 0.85,
            gravity: Offset(0.3, 1),
          ),
        ),
        borderRadius: PhysicalSurface.stadium,
      ),
    ]);
  });

  testWidgets('glass and lens', (tester) async {
    const picture = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2B3A55), Color(0xFFB8572A), Color(0xFFF2C14E)],
        ),
      ),
      child: Center(child: FlutterLogo(size: 48)),
    );
    await expectSheet(tester, 'glass_and_lens', [
      const PhysicalGlass(borderRadius: Sheet.radius, child: picture),
      const PhysicalLens(borderRadius: Sheet.radius, child: picture),
      const PhysicalLens(
        borderRadius: Sheet.radius,
        optics: LensOptics(
          refraction: 1.2,
          aberration: 0.8,
          tint: Sheet.accent,
          tintStrength: 0.3,
        ),
        child: picture,
      ),
      const PhysicalSurface(
        color: Sheet.body,
        borderRadius: Sheet.radius,
        isFaceCovered: true,
        child: picture,
      ),
    ]);
  });

  testWidgets('backgrounds', (tester) async {
    await expectSheet(tester, 'backgrounds', [
      const PhysicalPegboard(color: Sheet.background, child: SizedBox.expand()),
      const PhysicalPegboard(
        color: Sheet.body,
        grid: PegboardGrid(pitch: 24),
        washStrength: 0.3,
        child: SizedBox.expand(),
      ),
      PhysicalDotGrid(
        columns: 6,
        rows: 6,
        dots: [
          for (var cell = 0; cell < 36; cell++)
            cell.isEven
                ? const PhysicalDot.bead(Sheet.accent)
                : const PhysicalDot.socket(Sheet.body),
        ],
      ),
    ]);
  });

  testWidgets('light and tone', (tester) async {
    Widget lit(Offset direction, LightTone tone) {
      return PhysicalLight(
        direction: AlwaysStoppedAnimation(direction),
        tone: AlwaysStoppedAnimation(tone),
        child: slab(PhysicalMaterial.gloss, color: Sheet.accent),
      );
    }

    final dusk = SkyLight.at(DateTime(2026, 6, 21, 20, 30)).tone;
    final night = SkyLight.at(DateTime(2026, 6, 21, 23)).tone;
    await expectSheet(tester, 'light_and_tone', [
      lit(Offset.zero, LightTone.neutral),
      lit(const Offset(0.8, 0), LightTone.neutral),
      lit(const Offset(-0.8, 0.6), LightTone.neutral),
      lit(const Offset(0, -0.9), LightTone.neutral),
      lit(Sheet.light, dusk),
      lit(Sheet.light, night),
    ]);
  });
}
