import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical/src/surface/physical_pressable.dart';

void main() {
  group('PhysicalMaterial', () {
    test('a press that springs back past rest stays a valid material', () {
      const overshoot = -0.2;

      for (final material in [
        PhysicalMaterial.gloss,
        PhysicalMaterial.bead,
        PhysicalMaterial.well,
      ]) {
        final sprung = material.pressed(overshoot);

        expect(sprung.relief, inInclusiveRange(-1, 1));
        expect(sprung.elevation, greaterThanOrEqualTo(material.elevation));
      }
    });

    test('a press pushed past fully down never lifts the shadow', () {
      const beyondDown = 1.3;

      expect(PhysicalMaterial.gloss.pressed(beyondDown).elevation, 0);
    });

    test('a texture is laid over a material without changing its shape', () {
      final wooden = PhysicalMaterial.gloss.withTexture(PhysicalTexture.walnut);

      expect(wooden.texture, PhysicalTexture.walnut);
      expect(wooden.bevel, PhysicalMaterial.gloss.bevel);
      expect(wooden.roughness, PhysicalMaterial.gloss.roughness);
      expect(wooden, isNot(PhysicalMaterial.gloss));
    });

    test('a pressed material keeps its texture', () {
      final stone = PhysicalMaterial.satin.withTexture(PhysicalTexture.granite);

      expect(stone.pressed(1).texture, PhysicalTexture.granite);
    });

    test('a texture at no strength counts as plain', () {
      expect(PhysicalTexture.none.isPlain, isTrue);
      expect(PhysicalTexture.walnut.faded(0).isPlain, isTrue);
      expect(PhysicalTexture.walnut.isPlain, isFalse);
    });

    test('modifiers stack on a preset without losing what it is', () {
      final worn = PhysicalTexture.mahogany.aged(0.5).imperfect(0.3).scaled(2);

      expect(worn.substance, PhysicalSubstance.wood);
      expect(worn.naturalColor, PhysicalTexture.mahogany.naturalColor);
      expect(worn.figure, PhysicalTexture.mahogany.figure);
      expect(worn.age, 0.5);
      expect(worn.imperfection, 0.3);
      expect(worn.scale, 2);
      expect(worn, isNot(PhysicalTexture.mahogany));
    });

    test('scratches can be laid out without changing how marked it is', () {
      final door = PhysicalTexture.oak.imperfect(0.6).scratched(
            direction: 1.2,
            spread: 0.1,
            clustering: 0.9,
          );

      expect(door.scratches, 0.6);
      expect(door.dents, 0.6);
      expect(door.scratchDirection, 1.2);
      expect(door.scratchSpread, 0.1);
      expect(door.scratchClustering, 0.9);
      expect(
        door.scratched(spread: 0.4).scratchDirection,
        door.scratchDirection,
      );
    });

    test('scratches and dents are set apart from each other', () {
      final bench = PhysicalTexture.oak.scratched(amount: 0.8).dented(0.2);

      expect(bench.scratches, 0.8);
      expect(bench.dents, 0.2);
      expect(bench.imperfection, 0.8);
      expect(bench.scratched(amount: 0.1).dents, 0.2);
      expect(bench.dented(0.9).scratches, 0.8);
      expect(bench.tinted(const Color(0xFF12A5A0)).dents, 0.2);
    });

    test('a tinted preset keeps its figure in another colour', () {
      const teal = Color(0xFF12A5A0);

      final tinted = PhysicalTexture.carrara.tinted(teal);

      expect(tinted.naturalColor, teal);
      expect(tinted.figure, PhysicalTexture.carrara.figure);
      expect(tinted.secondColor, PhysicalTexture.carrara.secondColor);
    });

    test('grain falls back to a darker shade of the body', () {
      const body = Color(0xFF808080);
      const plainWood = PhysicalTexture.wood();

      final grain = plainWood.secondColorOn(body);

      expect(grain.computeLuminance(), lessThan(body.computeLuminance()));
    });

    test('every preset is named once', () {
      final all = [
        ...PhysicalTexture.woods.values,
        ...PhysicalTexture.stones.values,
        ...PhysicalTexture.metals.values,
      ];

      expect(all.toSet(), hasLength(all.length));
    });

    test('pressing flattens the relief and removes the elevation', () {
      final pressed = PhysicalMaterial.gloss.pressed(1);

      expect(pressed.elevation, 0);
      expect(pressed.relief, lessThan(PhysicalMaterial.gloss.relief));
      expect(pressed.shadowReach, 0);
    });

    test('a resting press leaves the material unchanged', () {
      expect(PhysicalMaterial.gloss.pressed(0), PhysicalMaterial.gloss);
    });
  });

  group('PhysicalSurface', () {
    testWidgets('takes the size of its child', (tester) async {
      await tester.pumpWidget(
        const Center(
          child: PhysicalSurface(
            color: Colors.red,
            borderRadius: PhysicalSurface.stadium,
            child: SizedBox(width: 120, height: 40),
          ),
        ),
      );

      expect(tester.getSize(find.byType(PhysicalSurface)), const Size(120, 40));
    });

    testWidgets('a change of light repaints without rebuilding the child',
        (tester) async {
      final direction = ValueNotifier(Offset.zero);
      addTearDown(direction.dispose);
      var builds = 0;

      await tester.pumpWidget(
        PhysicalLight(
          direction: direction,
          child: Center(
            child: PhysicalSurface(
              color: Colors.red,
              child: Builder(
                builder: (context) {
                  builds++;
                  return const SizedBox(width: 120, height: 40);
                },
              ),
            ),
          ),
        ),
      );
      direction.value = const Offset(0.3, -0.2);
      await tester.pump();

      expect(builds, 1);
    });
  });

  group('PhysicalPressable', () {
    testWidgets('reports taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: PhysicalPressable(
              onTap: () => taps++,
              color: Colors.red,
              child: const SizedBox(width: 120, height: 40),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PhysicalPressable));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('physicalButtonStyle', () {
    testWidgets('keeps Material button behaviour', (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ElevatedButton(
              style: physicalButtonStyle(
                color: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => presses++,
              child: const Text('Save'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(presses, 1);
      expect(find.byType(PhysicalButtonBackground), findsOneWidget);
    });
  });
}
