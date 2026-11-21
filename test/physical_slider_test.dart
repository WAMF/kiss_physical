import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Fixture {
  static const width = 232.0;
  static const height = 32.0;
  static const hoursPerDay = 24.0;
  static const quarterHours = 96;
  static const middle = Offset(width / 2, height / 2);
  static const nearMiddle = Offset(width / 2 + 3, height / 2);
  static const pastTheEnd = Offset(width * 2, 0);
}

Widget _slider({
  required double value,
  required ValueChanged<double> onChanged,
  int? divisions,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _Fixture.width,
        child: PhysicalSlider(
          value: value,
          max: _Fixture.hoursPerDay,
          divisions: divisions,
          onChanged: onChanged,
          barColor: Colors.red,
          trackColor: Colors.grey,
          thumbColor: Colors.white,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the track spans the slider and the bar ends under the bead', (
    tester,
  ) async {
    await tester.pumpWidget(
      _slider(value: _Fixture.hoursPerDay / 2, onChanged: (_) {}),
    );

    final surfaces = find.byType(PhysicalSurface);
    final track = tester.getRect(surfaces.at(0));
    final bar = tester.getRect(surfaces.at(1));
    final bead = tester.getRect(surfaces.at(2));
    expect(track.width, _Fixture.width);
    expect(bar.right, bead.center.dx);
  });

  testWidgets('tapping the track moves the value there', (tester) async {
    double? chosen;
    await tester.pumpWidget(_slider(value: 0, onChanged: (v) => chosen = v));

    await tester.tapAt(_Fixture.middle);

    expect(chosen, _Fixture.hoursPerDay / 2);
  });

  testWidgets('dragging past the end stops at the maximum', (tester) async {
    double? chosen;
    await tester.pumpWidget(_slider(value: 0, onChanged: (v) => chosen = v));

    await tester.dragFrom(_Fixture.middle, _Fixture.pastTheEnd);

    expect(chosen, _Fixture.hoursPerDay);
  });

  testWidgets('snaps to the nearest division', (tester) async {
    double? chosen;
    await tester.pumpWidget(
      _slider(
        value: 0,
        divisions: _Fixture.quarterHours,
        onChanged: (v) => chosen = v,
      ),
    );

    await tester.tapAt(_Fixture.nearMiddle);

    expect(chosen, _Fixture.hoursPerDay / 2 + 0.25);
  });

  testWidgets('the bead sits where the value is', (tester) async {
    await tester.pumpWidget(
      _slider(value: _Fixture.hoursPerDay / 2, onChanged: (_) {}),
    );

    final bead = tester.getCenter(find.byType(PhysicalSurface).last);

    expect(bead.dx, _Fixture.width / 2);
  });
}
