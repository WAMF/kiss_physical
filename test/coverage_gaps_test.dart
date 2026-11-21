import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical/src/light/light_vector.dart';
import 'package:kiss_physical/src/shader/physical_shader_brush.dart';
import 'package:kiss_physical/src/shader/shader_programs.dart';

class _Sample {
  static const color = Color(0xFF3366CC);
  static const tolerance = 1e-9;
  static const side = 120.0;
}

double _lengthOf(LightVector light) {
  return math.sqrt(light.x * light.x + light.y * light.y + light.z * light.z);
}

Widget _framed(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox.square(dimension: _Sample.side, child: child),
    ),
  );
}

void main() {
  group('LightVector.towards', () {
    test('a light straight overhead points out of the screen', () {
      final light = LightVector.towards(Offset.zero);

      expect(light.x, 0);
      expect(light.y, 0);
      expect(light.z, 1);
    });

    test('is always a unit vector', () {
      for (final direction in const [
        Offset(0.3, -0.2),
        Offset(-1, 1),
        Offset(40, -90),
      ]) {
        expect(
          _lengthOf(LightVector.towards(direction)),
          closeTo(1, _Sample.tolerance),
        );
      }
    });

    test('stays in front of the screen however far it leans', () {
      final farAside = LightVector.towards(const Offset(1000, 0));

      expect(farAside.z, greaterThan(0.5));
      expect(farAside.x, greaterThan(0));
    });

    test('leans the way it is pointed', () {
      final light = LightVector.towards(const Offset(-0.25, -0.45));

      expect(light.x, lessThan(0));
      expect(light.y, lessThan(0));
    });
  });

  group('PhysicalShaderBrush', () {
    test('has nothing to draw with until it is given a loaded program', () {
      final brush = PhysicalShaderBrush();
      addTearDown(brush.dispose);

      expect(brush.isReady, isFalse);
      brush.program = ValueNotifier(null);
      expect(brush.isReady, isFalse);
    });

    testWidgets('is ready once its program has loaded', (tester) async {
      final program = ShaderPrograms.surface(SurfaceProgram.plain);
      await tester.runAsync(program.load);
      final brush = PhysicalShaderBrush(program.whenLoaded);
      addTearDown(brush.dispose);

      expect(brush.isReady, isTrue);
      expect(brush.paint.shader, same(brush.shader));
    });
  });

  group('PhysicalLens', () {
    testWidgets('shows its child and takes its size', (tester) async {
      await tester.pumpWidget(
        _framed(
          const PhysicalLens(child: ColoredBox(color: _Sample.color)),
        ),
      );

      expect(find.byType(ColoredBox), findsOneWidget);
      expect(
        tester.getSize(find.byType(PhysicalLens)),
        const Size.square(_Sample.side),
      );
    });

    testWidgets('passes taps through to its child', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _framed(
          PhysicalLens(
            child: GestureDetector(
              onTap: () => taps++,
              child: const ColoredBox(color: _Sample.color),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PhysicalLens));

      expect(taps, 1);
    });

    testWidgets('repaints for the light without rebuilding its child', (
      tester,
    ) async {
      final direction = ValueNotifier(Offset.zero);
      addTearDown(direction.dispose);
      var builds = 0;
      await tester.pumpWidget(
        PhysicalLight(
          direction: direction,
          child: _framed(
            PhysicalLens(
              child: Builder(
                builder: (context) {
                  builds++;
                  return const ColoredBox(color: _Sample.color);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      direction.value = const Offset(0.4, 0.1);
      await tester.pump();

      expect(builds, 1);
    });
  });

  group('components build and lay out', () {
    testWidgets('a pill button is pressed and frosts when it cannot be', (
      tester,
    ) async {
      var presses = 0;
      Widget button({required bool isEnabled}) {
        return MaterialApp(
          home: Center(
            child: PhysicalPillButton(
              color: _Sample.color,
              foregroundColor: Colors.white,
              onPressed: isEnabled ? () => presses++ : null,
              child: const Text('Save'),
            ),
          ),
        );
      }

      await tester.pumpWidget(button(isEnabled: true));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(presses, 1);
      final lively = tester.widget<PhysicalSurface>(
        find.byType(PhysicalSurface),
      );

      await tester.pumpWidget(button(isEnabled: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      final frosted = tester.widget<PhysicalSurface>(
        find.byType(PhysicalSurface),
      );

      expect(presses, 1);
      expect(lively.color, _Sample.color);
      expect(frosted.color, isNot(_Sample.color));
    });

    testWidgets('a card clips what it holds', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PhysicalCard(
              width: _Sample.side,
              height: _Sample.side,
              child: ColoredBox(color: _Sample.color),
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<PhysicalSurface>(find.byType(PhysicalSurface))
            .clipBehavior,
        Clip.hardEdge,
      );
      expect(
        tester.getSize(find.byType(PhysicalCard)),
        const Size.square(_Sample.side),
      );
    });

    testWidgets('a raised panel floats and a flat one lies flush', (
      tester,
    ) async {
      PhysicalMaterial materialOf(WidgetTester tester) {
        return tester
            .widget<PhysicalSurface>(find.byType(PhysicalSurface))
            .material;
      }

      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: PhysicalPanel(child: SizedBox.square())),
        ),
      );
      expect(materialOf(tester), PhysicalMaterial.panel);

      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PhysicalPanel(isRaised: true, child: SizedBox.square()),
          ),
        ),
      );
      expect(materialOf(tester), PhysicalMaterial.floatingPanel);
    });
  });

  group('a surface makes only what it needs', () {
    testWidgets('a plain body draws without rain or a bake', (
      tester,
    ) async {
      await tester.runAsync(PhysicalShader.precacheAll);
      await tester.pumpWidget(
        _framed(
          const PhysicalSurface(
            color: _Sample.color,
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('rain starts when it is asked for and dries after', (
      tester,
    ) async {
      await tester.runAsync(PhysicalShader.precacheAll);
      Widget body(PhysicalMaterial material) {
        return _framed(
          PhysicalSurface(
            color: _Sample.color,
            material: material,
            child: const SizedBox.expand(),
          ),
        );
      }

      await tester.pumpWidget(body(PhysicalMaterial.satin));
      await tester.pump();
      await tester.pumpWidget(
        body(PhysicalMaterial.satin.withEffect(const PhysicalEffect.rain())),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(body(PhysicalMaterial.satin));
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
    });
  });
}
