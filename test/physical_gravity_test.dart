import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Fixture {
  static const tippedLeft = Offset(-0.6, 0.4);
}

void main() {
  Future<Offset> gravityUnder(
    WidgetTester tester,
    Widget Function(Widget child) wrap,
  ) async {
    late Offset found;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            found = PhysicalLight.gravityOf(context).value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return found;
  }

  testWidgets('with no light above it a body stands upright', (tester) async {
    final gravity = await gravityUnder(tester, (child) => child);

    expect(gravity, PhysicalLight.upright.value);
  });

  testWidgets('a body takes its gravity from the light above it',
      (tester) async {
    final tilted = ValueNotifier(_Fixture.tippedLeft);
    addTearDown(tilted.dispose);

    final gravity = await gravityUnder(
      tester,
      (child) => PhysicalLight(
        direction: PhysicalLight.still,
        gravity: tilted,
        child: child,
      ),
    );

    expect(gravity, _Fixture.tippedLeft);
  });

  test('water and flames follow the world unless told which way', () {
    expect(const PhysicalEffect.rain().gravity, isNull);
    expect(const PhysicalEffect.flame().gravity, isNull);
    expect(
      const PhysicalEffect.flame(gravity: _Fixture.tippedLeft).gravity,
      _Fixture.tippedLeft,
    );
  });
}
