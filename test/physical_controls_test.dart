import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Sample {
  static const color = Color(0xFF3366CC);
  static const diameter = 48.0;
  static const sliderWidth = 232.0;
  static const steps = 10;
  static const start = 0.5;
  static const oneStep = 1 / steps;
  static const nearly = 0.01;
  static const visibleDip = 0.2;
}

Widget _pressable({
  required VoidCallback? onTap,
  PhysicalMaterial material = PhysicalMaterial.gloss,
  VoidCallback? onHold,
  bool repeatsWhileHeld = false,
}) {
  return PhysicalPressable(
    onTap: onTap,
    onHold: onHold,
    repeatsWhileHeld: repeatsWhileHeld,
    color: _Sample.color,
    material: material,
    child: const SizedBox.square(dimension: _Sample.diameter),
  );
}

/// The haptics asked of the platform from now on, by name.
List<Object?> _hapticsOf(WidgetTester tester) {
  final asked = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') asked.add(call.arguments);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return asked;
}

Widget _app(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

PhysicalSurface _surfaceIn(WidgetTester tester, Finder scope) {
  return tester.widget<PhysicalSurface>(
    find.descendant(of: scope, matching: find.byType(PhysicalSurface)).first,
  );
}

Widget _slider({
  required double value,
  ValueChanged<double>? onChanged,
  ValueChanged<double>? onChangeEnd,
  FocusNode? focusNode,
  TextDirection direction = TextDirection.ltr,
}) {
  return _app(
    Directionality(
      textDirection: direction,
      child: SizedBox(
        width: _Sample.sliderWidth,
        child: PhysicalSlider(
          value: value,
          divisions: _Sample.steps,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
          focusNode: focusNode,
          semanticLabel: 'Level',
          barColor: _Sample.color,
          trackColor: _Sample.color,
          thumbColor: _Sample.color,
        ),
      ),
    ),
  );
}

void main() {
  group('PhysicalPressable', () {
    testWidgets('is pressed by Enter and by Space while focused', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var presses = 0;
      await tester.pumpWidget(
        _app(
          PhysicalPressable(
            onTap: () => presses++,
            color: _Sample.color,
            focusNode: focus,
            child: const SizedBox.square(dimension: _Sample.diameter),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(presses, 2);
    });

    testWidgets('sinks under the finger and comes back to rest', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_pressable(onTap: () {})));
      final surface = _surfaceIn(tester, find.byType(PhysicalPressable));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PhysicalPressable)),
      );
      await tester.pumpAndSettle();
      expect(surface.press!.value, closeTo(1, _Sample.nearly));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(surface.press!.value, closeTo(0, _Sample.nearly));
    });

    testWidgets('a quick tap dips and springs past rest, as plastic does', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_pressable(onTap: () {})));
      final press = _surfaceIn(tester, find.byType(PhysicalPressable)).press!;
      var deepest = 0.0;
      var highest = 0.0;
      press.addListener(() {
        deepest = math.max(deepest, press.value);
        highest = math.min(highest, press.value);
      });

      await tester.tap(find.byType(PhysicalPressable));
      await tester.pumpAndSettle();

      expect(deepest, greaterThan(_Sample.visibleDip));
      expect(highest, lessThan(0));
    });

    testWidgets('stone comes back to rest without springing past it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _pressable(
            onTap: () {},
            material: PhysicalMaterial.gloss.withTexture(
              PhysicalTexture.granite,
            ),
          ),
        ),
      );
      final press = _surfaceIn(tester, find.byType(PhysicalPressable)).press!;
      var highest = 0.0;
      press.addListener(() => highest = math.min(highest, press.value));

      await tester.tap(find.byType(PhysicalPressable));
      await tester.pumpAndSettle();

      expect(highest, greaterThan(-_Sample.nearly));
    });

    testWidgets('taps the hand as it goes down, as heavily as it is made', (
      tester,
    ) async {
      final taps = _hapticsOf(tester);
      await tester.pumpWidget(
        _app(
          _pressable(
            onTap: () {},
            material: PhysicalMaterial.gloss.withTexture(
              PhysicalTexture.granite,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PhysicalPressable));
      await tester.pumpAndSettle();

      expect(taps, ['HapticFeedbackType.heavyImpact']);
    });

    testWidgets('stays quiet where haptics are turned off', (tester) async {
      final taps = _hapticsOf(tester);
      await tester.pumpWidget(
        _app(
          PhysicalHaptics(isEnabled: false, child: _pressable(onTap: () {})),
        ),
      );

      await tester.tap(find.byType(PhysicalPressable));
      await tester.pumpAndSettle();

      expect(taps, isEmpty);
    });

    testWidgets('repeats its tap while held and adds none on letting go', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(
        _app(_pressable(onTap: () => presses++, repeatsWhileHeld: true)),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PhysicalPressable)),
      );
      await tester.pump(HoldRepeater.defaultDelay);
      await tester.pump(HoldRepeater.defaultSlowest);
      final whileHeld = presses;
      await gesture.up();
      await tester.pumpAndSettle();

      expect(whileHeld, greaterThan(1));
      expect(presses, whileHeld);
    });

    testWidgets('a quick tap on a repeating surface counts once', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(
        _app(_pressable(onTap: () => presses++, repeatsWhileHeld: true)),
      );

      await tester.tap(find.byType(PhysicalPressable));
      await tester.pumpAndSettle();

      expect(presses, 1);
    });

    testWidgets('calls onHold when held and stays down until let go', (
      tester,
    ) async {
      var holds = 0;
      var presses = 0;
      await tester.pumpWidget(
        _app(_pressable(onTap: () => presses++, onHold: () => holds++)),
      );
      final press = _surfaceIn(tester, find.byType(PhysicalPressable)).press!;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PhysicalPressable)),
      );
      await tester.pump(kLongPressTimeout);
      await tester.pumpAndSettle();
      expect(holds, 1);
      expect(press.value, closeTo(1, _Sample.nearly));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(presses, 0);
      expect(press.value, closeTo(0, _Sample.nearly));
    });

    testWidgets('cannot take focus when it has nothing to do', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _app(
          PhysicalPressable(
            onTap: null,
            color: _Sample.color,
            focusNode: focus,
            child: const SizedBox.square(dimension: _Sample.diameter),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();

      expect(focus.hasFocus, isFalse);
    });
  });

  group('PhysicalIconButton', () {
    testWidgets('is named by its tooltip for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          PhysicalIconButton(
            icon: const Icon(Icons.add),
            diameter: _Sample.diameter,
            tooltip: 'Add',
            onPressed: () {},
          ),
        ),
      );

      expect(find.bySemanticsLabel('Add'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('prefers its semantic label to its tooltip', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          PhysicalIconButton(
            icon: const Icon(Icons.add),
            diameter: _Sample.diameter,
            tooltip: 'Add',
            semanticLabel: 'Add a photo',
            onPressed: () {},
          ),
        ),
      );

      expect(find.bySemanticsLabel('Add a photo'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('is frosted and flattened when it cannot be pressed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const PhysicalIconButton(
            icon: Icon(Icons.add),
            diameter: _Sample.diameter,
            color: _Sample.color,
            onPressed: null,
          ),
        ),
      );

      final surface = _surfaceIn(tester, find.byType(PhysicalIconButton));
      expect(surface.color, isNot(_Sample.color));
      expect(surface.material.elevation, 0);
    });

    testWidgets('fades whatever it shows when it cannot be pressed', (
      tester,
    ) async {
      const picture = SizedBox.square(dimension: 20);
      await tester.pumpWidget(
        _app(
          const PhysicalIconButton(
            icon: picture,
            diameter: _Sample.diameter,
            onPressed: null,
          ),
        ),
      );

      final faded = find.ancestor(
        of: find.byWidget(picture),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(faded.first).opacity, lessThan(1));
    });

    testWidgets('keeps its colour when it can be pressed', (tester) async {
      await tester.pumpWidget(
        _app(
          PhysicalIconButton(
            icon: const Icon(Icons.add),
            diameter: _Sample.diameter,
            color: _Sample.color,
            onPressed: () {},
          ),
        ),
      );

      final surface = _surfaceIn(tester, find.byType(PhysicalIconButton));
      expect(surface.color, _Sample.color);
      expect(surface.material, PhysicalMaterial.bead);
    });
  });

  group('PhysicalSlider', () {
    testWidgets('moves a step with the arrow keys while focused', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final values = <double>[];
      await tester.pumpWidget(
        _slider(
          value: _Sample.start,
          onChanged: values.add,
          focusNode: focus,
        ),
      );
      focus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

      expect(values, [
        closeTo(_Sample.start + _Sample.oneStep, 1e-9),
        closeTo(_Sample.start - _Sample.oneStep, 1e-9),
        closeTo(_Sample.start + _Sample.oneStep, 1e-9),
        closeTo(_Sample.start - _Sample.oneStep, 1e-9),
      ]);
    });

    testWidgets('the right arrow lowers the value when reading right to left', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final values = <double>[];
      await tester.pumpWidget(
        _slider(
          value: _Sample.start,
          onChanged: values.add,
          focusNode: focus,
          direction: TextDirection.rtl,
        ),
      );
      focus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      expect(values.single, closeTo(_Sample.start - _Sample.oneStep, 1e-9));
    });

    testWidgets('reports where a drag left the bead', (tester) async {
      var value = _Sample.start;
      double? ended;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _slider(
            value: value,
            onChanged: (next) => setState(() => value = next),
            onChangeEnd: (last) => ended = last,
          ),
        ),
      );

      await tester.drag(find.byType(PhysicalSlider), const Offset(60, 0));
      await tester.pump();

      expect(ended, value);
      expect(value, greaterThan(_Sample.start));
    });

    testWidgets('ignores touch and focus, and is frosted, with no onChanged', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _slider(value: _Sample.start, focusNode: focus),
      );
      focus.requestFocus();
      await tester.pump();

      await tester.tap(find.byType(PhysicalSlider), warnIfMissed: false);

      expect(focus.hasFocus, isFalse);
      final surfaces = tester.widgetList<PhysicalSurface>(
        find.byType(PhysicalSurface),
      );
      expect(surfaces.last.color, isNot(_Sample.color));
    });

    testWidgets('is as tall as the bead it is given', (tester) async {
      const diameter = 44.0;
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: _Sample.sliderWidth,
            child: PhysicalSlider(
              value: _Sample.start,
              onChanged: (_) {},
              thumbDiameter: diameter,
              barColor: _Sample.color,
              trackColor: _Sample.color,
              thumbColor: _Sample.color,
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(PhysicalSlider)).height, diameter);
    });
  });
}
