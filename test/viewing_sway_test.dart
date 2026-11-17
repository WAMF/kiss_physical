import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/src/light/viewing_sway.dart';

class _Fixture {
  static const upright = Offset(0, -0.7);
  static const leanedRight = Offset(0.1, -0.7);
  static const flungAside = Offset(0.9, -0.7);
  static const manySamples = 400;
}

void main() {
  test('the first pose is the line of sight, so there is no sway', () {
    expect(ViewingSway().follow(_Fixture.upright), Offset.zero);
  });

  test('a fresh tilt sways towards the side that came nearer', () {
    final sway = ViewingSway()..follow(_Fixture.upright);

    final moved = sway.follow(_Fixture.leanedRight);

    expect(moved.dx, closeTo(0.1, 1e-9));
    expect(moved.dy, closeTo(0, 1e-9));
  });

  test('a pose held for a while becomes the line of sight again', () {
    final sway = ViewingSway()..follow(_Fixture.upright);

    var last = Offset.infinite;
    for (var sample = 0; sample < _Fixture.manySamples; sample++) {
      last = sway.follow(_Fixture.leanedRight);
    }

    expect(last.distance, lessThan(0.001));
  });

  test('never sways beyond its reach', () {
    final sway = ViewingSway()..follow(_Fixture.upright);

    final moved = sway.follow(_Fixture.flungAside);

    expect(moved.distance, closeTo(ViewingSway.defaultReach, 1e-9));
  });

  test('forgets the pose when reset', () {
    final sway = ViewingSway()
      ..follow(_Fixture.upright)
      ..reset();

    expect(sway.follow(_Fixture.leanedRight), Offset.zero);
  });
}
