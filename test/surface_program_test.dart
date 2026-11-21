import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical/src/shader/shader_programs.dart';

void main() {
  group('SurfaceProgram.of', () {
    test('a bare body takes the plain program', () {
      expect(SurfaceProgram.of(PhysicalMaterial.satin), SurfaceProgram.plain);
    });

    test('each substance takes its own program', () {
      final programs = {
        PhysicalTexture.walnut: SurfaceProgram.wood,
        PhysicalTexture.brass: SurfaceProgram.metal,
        PhysicalTexture.plastic: SurfaceProgram.plastic,
        PhysicalTexture.granite: SurfaceProgram.stone,
        PhysicalTexture.carrara: SurfaceProgram.marble,
      };

      for (final MapEntry(key: texture, value: program) in programs.entries) {
        expect(
          SurfaceProgram.of(PhysicalMaterial.satin.withTexture(texture)),
          program,
        );
      }
    });

    test('effects on a textured body stay with its substance', () {
      final burning = PhysicalMaterial.satin
          .withTexture(PhysicalTexture.oak)
          .withEffect(const PhysicalEffect.flame())
          .withEffect(const PhysicalEffect.rain());

      expect(SurfaceProgram.of(burning), SurfaceProgram.wood);
    });

    test('effects, glass and dew on a bare body take the effects program', () {
      final bodies = [
        PhysicalMaterial.satin.withEffect(const PhysicalEffect.neon()),
        PhysicalMaterial.gloss.withVessel(const PhysicalVessel.glass()),
        PhysicalMaterial.satin.withDecals(const PhysicalDecals(dew: 0.5)),
      ];

      for (final body in bodies) {
        expect(SurfaceProgram.of(body), SurfaceProgram.effects);
      }
    });

    test('a texture faded to nothing is no texture', () {
      final faded =
          PhysicalMaterial.satin.withTexture(PhysicalTexture.walnut.faded(0));

      expect(SurfaceProgram.of(faded), SurfaceProgram.plain);
    });
  });

  group('PhysicalLight.fixed', () {
    testWidgets('holds the light where it is put, in the tone given', (
      tester,
    ) async {
      const direction = Offset(0.4, -0.2);
      const tone = LightTone(
        key: LightColor(1, 0.8, 0.6),
        fill: LightColor(0.5, 0.6, 0.9),
      );
      late BuildContext inside;
      await tester.pumpWidget(
        PhysicalLight.fixed(
          direction: direction,
          tone: tone,
          child: Builder(
            builder: (context) {
              inside = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(PhysicalLight.of(inside).value, direction);
      expect(PhysicalLight.toneOf(inside).value, tone);
    });

    testWidgets('rests where a light with no direction rests', (tester) async {
      late BuildContext inside;
      await tester.pumpWidget(
        PhysicalLight.fixed(
          child: Builder(
            builder: (context) {
              inside = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(PhysicalLight.of(inside).value, PhysicalLight.still.value);
    });
  });

  group('PhysicalCard shapes', () {
    PhysicalSurface surfaceOf(WidgetTester tester) {
      return tester.widget<PhysicalSurface>(find.byType(PhysicalSurface));
    }

    testWidgets('a pill has fully rounded ends and a glossy finish', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: PhysicalCard.pill(child: SizedBox(height: 20))),
        ),
      );

      expect(surfaceOf(tester).borderRadius, PhysicalSurface.stadium);
      expect(surfaceOf(tester).material, PhysicalMaterial.gloss);
    });

    testWidgets('a disc is as wide as it is tall', (tester) async {
      const diameter = 64.0;
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PhysicalCard.disc(
              diameter: diameter,
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(PhysicalCard)),
        const Size.square(diameter),
      );
      expect(surfaceOf(tester).material, PhysicalMaterial.bead);
    });

    testWidgets('a docked panel is rounded on its top corners only', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Align(
            alignment: Alignment.bottomCenter,
            child: PhysicalPanel.bottom(child: SizedBox(height: 40)),
          ),
        ),
      );

      final radius = surfaceOf(tester).borderRadius;
      expect(radius.topLeft, isNot(Radius.zero));
      expect(radius.bottomLeft, Radius.zero);
      expect(surfaceOf(tester).clipBehavior, Clip.hardEdge);
    });
  });
}
