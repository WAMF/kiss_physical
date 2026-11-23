import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Sample {
  static const color = Color(0xFF3366CC);
  static const track = Color(0xFF2A2A2E);
  static const width = 300.0;
  static const flick = 1500.0;
  static const nudge = Offset(4, 0);
  static const across = Offset(60, 0);
  static const frame = Duration(milliseconds: 16);
  static const partOfALap = Duration(milliseconds: 300);
  static const periods = {'day': 'Day', 'week': 'Week', 'month': 'Month'};
}

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(child: SizedBox(width: _Sample.width, child: child)),
      ),
    ),
  );
}

Widget _switch({
  required bool value,
  required ValueChanged<bool>? onChanged,
  FocusNode? focusNode,
}) {
  return Center(
    child: PhysicalSwitch(
      value: value,
      onChanged: onChanged,
      focusNode: focusNode,
      semanticLabel: 'Reminders',
      activeColor: _Sample.color,
      trackColor: _Sample.track,
      thumbColor: _Sample.color,
    ),
  );
}

Widget _segments({
  required String selected,
  required ValueChanged<String>? onChanged,
  FocusNode? focusNode,
}) {
  return PhysicalSegmentedControl<String>(
    segments: {
      for (final MapEntry(:key, :value) in _Sample.periods.entries)
        key: Text(value),
    },
    selected: selected,
    onChanged: onChanged,
    focusNode: focusNode,
    trackColor: _Sample.track,
    thumbColor: _Sample.color,
  );
}

/// A control that keeps the value it is given, as an app would.
class _Held<T> extends StatefulWidget {
  const _Held({required this.initial, required this.builder});

  final T initial;
  final Widget Function(T value, ValueChanged<T> onChanged) builder;

  @override
  State<_Held<T>> createState() => _HeldState<T>();
}

class _HeldState<T> extends State<_Held<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return widget.builder(_value, (value) => setState(() => _value = value));
  }
}

double _thumbLeft(WidgetTester tester, Finder control) {
  final surfaces = find.descendant(
    of: control,
    matching: find.byType(PhysicalSurface),
  );
  return tester.getTopLeft(surfaces.at(1)).dx;
}

void main() {
  group('PhysicalSwitch', () {
    testWidgets('a tap flips it', (tester) async {
      final chosen = <bool>[];
      await tester.pumpWidget(
        _app(_switch(value: false, onChanged: chosen.add)),
      );

      await tester.tap(find.byType(PhysicalSwitch));

      expect(chosen, [true]);
    });

    testWidgets('the bead springs to the other end when it is flipped', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _Held<bool>(
            initial: false,
            builder: (value, onChanged) =>
                _switch(value: value, onChanged: onChanged),
          ),
        ),
      );
      final control = find.byType(PhysicalSwitch);
      final off = _thumbLeft(tester, control);

      await tester.tap(control);
      await tester.pump();
      await tester.pump(_Sample.frame);
      final onTheWay = _thumbLeft(tester, control);
      await tester.pumpAndSettle();

      expect(onTheWay, greaterThan(off));
      expect(_thumbLeft(tester, control), greaterThan(onTheWay));
    });

    testWidgets('a flick towards on turns it on', (tester) async {
      final chosen = <bool>[];
      await tester.pumpWidget(
        _app(_switch(value: false, onChanged: chosen.add)),
      );

      await tester.fling(
        find.byType(PhysicalSwitch),
        _Sample.nudge,
        _Sample.flick,
      );
      await tester.pumpAndSettle();

      expect(chosen, [true]);
    });

    testWidgets('a drag brought most of the way back leaves it as it was', (
      tester,
    ) async {
      final chosen = <bool>[];
      await tester.pumpWidget(
        _app(_switch(value: false, onChanged: chosen.add)),
      );
      final control = find.byType(PhysicalSwitch);
      final off = _thumbLeft(tester, control);

      final gesture = await tester.startGesture(tester.getCenter(control));
      await gesture.moveBy(_Sample.across);
      await gesture.moveBy(-_Sample.across + _Sample.nudge);
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(chosen, isEmpty);
      expect(_thumbLeft(tester, control), closeTo(off, 1));
    });

    testWidgets('on is at the start when reading right to left', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _switch(value: true, onChanged: (_) {}),
          direction: TextDirection.rtl,
        ),
      );
      final control = find.byType(PhysicalSwitch);

      expect(
        _thumbLeft(tester, control),
        lessThan(
            tester.getCenter(control).dx - PhysicalSwitch.defaultHeight / 2,),
      );
    });

    testWidgets('is flipped by Space while focused', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final chosen = <bool>[];
      await tester.pumpWidget(
        _app(_switch(value: true, onChanged: chosen.add, focusNode: focus)),
      );
      focus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      expect(chosen, [false]);
    });

    testWidgets('tells screen readers its name and whether it is on', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(_switch(value: true, onChanged: (_) {})));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Reminders')),
        isSemantics(
          label: 'Reminders',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('does nothing when it cannot be changed', (tester) async {
      await tester.pumpWidget(_app(_switch(value: false, onChanged: null)));

      await tester.tap(find.byType(PhysicalSwitch));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('PhysicalSegmentedControl', () {
    testWidgets('tapping a choice chooses it', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(
        _app(_segments(selected: 'day', onChanged: chosen.add)),
      );

      await tester.tap(find.text('Month'));

      expect(chosen, ['month']);
    });

    testWidgets('tapping the chosen one changes nothing', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(
        _app(_segments(selected: 'day', onChanged: chosen.add)),
      );

      await tester.tap(find.text('Day'));

      expect(chosen, isEmpty);
    });

    testWidgets('the thumb slides under the choice and rests there', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _Held<String>(
            initial: 'day',
            builder: (value, onChanged) =>
                _segments(selected: value, onChanged: onChanged),
          ),
        ),
      );
      final control = find.byType(PhysicalSegmentedControl<String>);
      final atDay = _thumbLeft(tester, control);

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      final atWeek = _thumbLeft(tester, control);

      expect(atWeek - atDay, closeTo(_Sample.width / 3, 3));
    });

    testWidgets('a throw carries the thumb to the choice it heads for', (
      tester,
    ) async {
      final chosen = <String>[];
      await tester.pumpWidget(
        _app(_segments(selected: 'day', onChanged: chosen.add)),
      );

      await tester.flingFrom(
        tester.getCenter(find.text('Day')),
        _Sample.across,
        _Sample.flick,
      );
      await tester.pumpAndSettle();

      expect(chosen, ['month']);
    });

    testWidgets('the arrow keys move the choice and stop at the ends', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final chosen = <String>[];
      await tester.pumpWidget(
        _app(
          _segments(selected: 'day', onChanged: chosen.add, focusNode: focus),
        ),
      );
      focus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      expect(chosen, ['week']);
    });

    testWidgets('tells screen readers which choice is chosen', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(_segments(selected: 'week', onChanged: (_) {})),
      );

      expect(
        tester.getSemantics(find.text('Week')),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.text('Day')),
        isSemantics(isSelected: false, isButton: true),
      );
      semantics.dispose();
    });
  });

  group('PhysicalTextField', () {
    testWidgets('takes what is typed', (tester) async {
      final typed = <String>[];
      await tester.pumpWidget(
        _app(PhysicalTextField(hintText: 'Search', onChanged: typed.add)),
      );

      await tester.enterText(find.byType(TextField), 'apple');

      expect(typed, ['apple']);
    });

    testWidgets('a tap anywhere in the well gives it focus', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _app(
          PhysicalTextField(
            focusNode: focus,
            leading: const Icon(Icons.search),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      expect(focus.hasFocus, isTrue);
    });

    testWidgets('cannot be typed into when it is not enabled', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _app(PhysicalTextField(focusNode: focus, enabled: false)),
      );

      await tester.tap(find.byType(PhysicalTextField));
      await tester.pump();

      expect(focus.hasFocus, isFalse);
    });

    testWidgets('lies in a recess', (tester) async {
      await tester.pumpWidget(_app(const PhysicalTextField()));

      final well = tester.widget<PhysicalSurface>(find.byType(PhysicalSurface));

      expect(well.material.relief, lessThan(0));
    });
  });

  group('PhysicalSpinner', () {
    Offset beadPlace(WidgetTester tester) {
      return tester.getCenter(find.byType(PhysicalSurface).last);
    }

    testWidgets('the bead keeps rolling round the dish', (tester) async {
      await tester.pumpWidget(
        _app(const Center(child: PhysicalSpinner(beadColor: _Sample.color))),
      );
      final first = beadPlace(tester);

      await tester.pump(_Sample.partOfALap);
      final second = beadPlace(tester);
      await tester.pump(_Sample.partOfALap);

      expect(second, isNot(first));
      expect(beadPlace(tester), isNot(second));
    });

    testWidgets('rolls slowly with reduced motion', (tester) async {
      Future<double> travelled({required bool isCalm}) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: isCalm),
            child: _app(
              Center(
                child: PhysicalSpinner(
                  key: ValueKey(isCalm),
                  beadColor: _Sample.color,
                ),
              ),
            ),
          ),
        );
        final from = beadPlace(tester);
        await tester.pump(_Sample.partOfALap);
        return (beadPlace(tester) - from).distance;
      }

      final lively = await travelled(isCalm: false);
      final calm = await travelled(isCalm: true);

      expect(calm, greaterThan(0));
      expect(calm, lessThan(lively));
    });

    testWidgets('says what is happening to screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const Center(
            child: PhysicalSpinner(
              beadColor: _Sample.color,
              semanticLabel: 'Loading',
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      semantics.dispose();
    });
  });
}
