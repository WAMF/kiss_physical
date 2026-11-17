import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

void main() {
  const height = 20.0;
  const restingCentre = Offset(400, 300);

  Future<void> pumpLayer(
    WidgetTester tester, {
    required ValueNotifier<Offset> sway,
    VoidCallback? onTap,
  }) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PhysicalLight(
          direction: PhysicalLight.still,
          sway: sway,
          child: Center(
            child: PhysicalParallaxLayer(
              child: GestureDetector(
                onTap: onTap,
                child: const ColoredBox(
                  color: Colors.white,
                  child: SizedBox.square(dimension: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('PhysicalParallaxLayer', () {
    test('shifts against the sway, by its height', () {
      expect(
        PhysicalParallaxLayer.shiftFor(const Offset(0.25, -0.1), height),
        const Offset(-5, 2),
      );
    });

    testWidgets('rests in place without sway', (tester) async {
      final sway = ValueNotifier(Offset.zero);
      addTearDown(sway.dispose);

      await pumpLayer(tester, sway: sway);

      expect(tester.getCenter(find.byType(ColoredBox)), restingCentre);
    });

    testWidgets('moves the opposite way to the sway', (tester) async {
      final sway = ValueNotifier(Offset.zero);
      addTearDown(sway.dispose);
      await pumpLayer(tester, sway: sway);

      sway.value = const Offset(0.25, 0);
      await tester.pump();

      expect(
        tester.getCenter(find.byType(ColoredBox)),
        restingCentre + const Offset(-5, 0),
      );
    });

    testWidgets('takes touches where it is drawn', (tester) async {
      var taps = 0;
      final sway = ValueNotifier(const Offset(0.35, 0));
      addTearDown(sway.dispose);
      await pumpLayer(tester, sway: sway, onTap: () => taps++);

      await tester.tapAt(restingCentre + const Offset(-26, 0));

      expect(taps, 1);
    });
  });
}
