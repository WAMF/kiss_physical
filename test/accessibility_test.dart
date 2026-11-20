import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical/src/shader/shader_programs.dart';

class _Sample {
  static const color = Color(0xFF3366CC);
  static const size = Size(400, 300);
  static const corner = Offset(390, 290);
}

Widget _animated({required bool reducedMotion}) {
  final effects = PhysicalMaterial.satin
      .withEffect(const PhysicalEffect.flame())
      .withEffect(const PhysicalEffect.rain())
      .withEffect(const PhysicalEffect.neon(flicker: 1));
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox.square(
          dimension: 120,
          child: PhysicalSurface(
            color: _Sample.color,
            material: effects,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('reduced motion', () {
    testWidgets('holds flames, rain and flicker still', (tester) async {
      await tester.pumpWidget(_animated(reducedMotion: true));
      await tester.pump();

      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('lets them move again when it is turned off', (tester) async {
      await tester.pumpWidget(_animated(reducedMotion: true));
      await tester.pump();

      await tester.pumpWidget(_animated(reducedMotion: false));
      await tester.pump();

      expect(tester.binding.hasScheduledFrame, isTrue);
    });
  });

  group('PointerLight', () {
    Future<BuildContext> pump(
      WidgetTester tester, {
      bool reducedMotion = false,
    }) async {
      late BuildContext inside;
      await tester.binding.setSurfaceSize(_Sample.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: PointerLight(
            child: Builder(
              builder: (context) {
                inside = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      return inside;
    }

    Future<void> hoverAt(WidgetTester tester, Offset position) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(position);
      await tester.pump();
    }

    testWidgets('carries the light and the sway towards the pointer', (
      tester,
    ) async {
      final inside = await pump(tester);

      await hoverAt(tester, _Sample.corner);

      final light = PhysicalLight.of(inside).value;
      final sway = PhysicalLight.swayOf(inside).value;
      expect(light.dx, greaterThan(0));
      expect(light.dy, greaterThan(0));
      expect(sway.dx, greaterThan(0));
      expect(sway.dy, greaterThan(0));
    });

    testWidgets('rests with reduced motion', (tester) async {
      final inside = await pump(tester, reducedMotion: true);

      await hoverAt(tester, _Sample.corner);

      expect(PhysicalLight.of(inside).value, PhysicalLight.still.value);
      expect(PhysicalLight.swayOf(inside).value, Offset.zero);
    });
  });

  group('PhysicalProgressBar', () {
    testWidgets('tells screen readers its name and how full it is', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PhysicalProgressBar(
            fraction: 0.6,
            semanticLabel: 'Upload',
            barColor: _Sample.color,
            trackColor: _Sample.color,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(PhysicalProgressBar)),
        matchesSemantics(label: 'Upload', value: '60%'),
      );
      semantics.dispose();
    });
  });

  group('PhysicalShader.hasFailed', () {
    testWidgets('turns true when a program cannot be compiled', (tester) async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() {
        FlutterError.onError = previous;
        ShaderPrograms.failed.value = false;
      });
      expect(PhysicalShader.hasFailed.value, isFalse);

      await tester.runAsync(ShaderProgram('no_such_program').load);

      expect(PhysicalShader.hasFailed.value, isTrue);
      expect(reported, hasLength(1));
    });
  });
}
