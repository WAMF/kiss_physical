import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Fixture {
  static const columns = 3;
  static const rows = 2;
  static const size = Size(90, 60);
  static const dots = <PhysicalDot?>[
    PhysicalDot.bead(Colors.red),
    PhysicalDot.socket(Colors.grey),
    null,
    PhysicalDot.bead(Colors.white),
    PhysicalDot.socket(Colors.grey),
    null,
  ];
}

Widget _grid(List<PhysicalDot?> dots) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox.fromSize(
        size: _Fixture.size,
        child: PhysicalDotGrid(
          columns: _Fixture.columns,
          rows: _Fixture.rows,
          dots: dots,
        ),
      ),
    ),
  );
}

void main() {
  test('dots of the same colour and kind are equal', () {
    expect(
      const PhysicalDot.bead(Colors.red),
      const PhysicalDot.bead(Colors.red),
    );
    expect(
      const PhysicalDot.bead(Colors.red),
      isNot(const PhysicalDot.socket(Colors.red)),
    );
  });

  testWidgets('fills the space it is given with a single painted layer',
      (tester) async {
    await tester.pumpWidget(_grid(_Fixture.dots));

    expect(tester.getSize(find.byType(PhysicalDotGrid)), _Fixture.size);
    expect(
      find.descendant(
        of: find.byType(PhysicalDotGrid),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('takes a new set of dots without error', (tester) async {
    await tester.pumpWidget(_grid(_Fixture.dots));
    await tester.pumpWidget(_grid(_Fixture.dots.reversed.toList()));

    expect(tester.takeException(), isNull);
  });
}
