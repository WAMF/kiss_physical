import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Fixture {
  static const trackWidth = 200.0;
  static const half = 0.5;
  static const beyondFull = 1.4;
}

Widget _bar(double fraction) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: _Fixture.trackWidth,
        child: PhysicalProgressBar(
          fraction: fraction,
          barColor: Colors.red,
          trackColor: Colors.grey,
        ),
      ),
    ),
  );
}

double _fillWidth(WidgetTester tester) {
  return tester.getSize(find.byType(PhysicalSurface).last).width;
}

void main() {
  testWidgets('fills the track in proportion to the fraction', (tester) async {
    await tester.pumpWidget(_bar(_Fixture.half));

    expect(_fillWidth(tester), _Fixture.trackWidth * _Fixture.half);
  });

  testWidgets('glides to a new fraction rather than jumping', (tester) async {
    await tester.pumpWidget(_bar(0));
    await tester.pumpWidget(_bar(1));
    await tester.pump(const Duration(milliseconds: 50));

    expect(_fillWidth(tester), greaterThan(0));
    expect(_fillWidth(tester), lessThan(_Fixture.trackWidth));

    await tester.pumpAndSettle();

    expect(_fillWidth(tester), _Fixture.trackWidth);
  });

  testWidgets('the track spans the width it is offered, however full', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: _Fixture.trackWidth,
            child: Column(
              children: [
                PhysicalProgressBar(
                  fraction: _Fixture.half,
                  barColor: Colors.red,
                  trackColor: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(PhysicalSurface).first).width,
      _Fixture.trackWidth,
    );
    expect(_fillWidth(tester), _Fixture.trackWidth * _Fixture.half);
  });

  testWidgets('never overflows the track', (tester) async {
    await tester.pumpWidget(_bar(_Fixture.beyondFull));

    expect(_fillWidth(tester), _Fixture.trackWidth);
  });
}
