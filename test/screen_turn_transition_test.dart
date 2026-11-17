import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/src/light/screen_turn_transition.dart';
import 'package:kiss_physical/src/light/up_vector_filter.dart';

void main() {
  const gravity = 9.80665;
  const swing = Duration(milliseconds: 300);
  const halfWay = Duration(milliseconds: 150);

  Offset upIn(ScreenTurn turn, double x, double y) {
    final filter = UpVectorFilter()
      ..addAccelerometer(x, y, 0)
      ..turnTo(turn);
    return filter.up!;
  }

  void expectSame(Offset actual, Offset expected) {
    expect(actual.dx, closeTo(expected.dx, 1e-9));
    expect(actual.dy, closeTo(expected.dy, 1e-9));
  }

  group('ScreenTurnTransition', () {
    test('changes nothing before any swing', () {
      final transition = ScreenTurnTransition();

      expect(transition.isSettledAfter(Duration.zero), isTrue);
      expectSame(
        transition.hold(const Offset(0.3, -0.4), Duration.zero),
        const Offset(0.3, -0.4),
      );
    });

    test('a swing starts from the direction shown in the old turn', () {
      for (final from in ScreenTurn.values) {
        for (final to in ScreenTurn.values) {
          final transition = ScreenTurnTransition()..begin(from, to);

          final held = transition.hold(
            upIn(to, gravity * 0.6, gravity * 0.8),
            Duration.zero,
          );

          expectSame(held, upIn(from, gravity * 0.6, gravity * 0.8));
        }
      }
    });

    test('a swing ends on the direction in the new turn', () {
      final transition = ScreenTurnTransition(duration: swing)
        ..begin(ScreenTurn.upright, ScreenTurn.topToLeft);
      final inNewTurn = upIn(ScreenTurn.topToLeft, gravity, 0);

      expect(transition.isSettledAfter(swing), isTrue);
      expectSame(transition.hold(inNewTurn, swing), inNewTurn);
    });

    test('half way through a quarter turn an eighth is left to swing', () {
      final transition = ScreenTurnTransition(
        duration: swing,
        curve: Curves.linear,
      )..begin(ScreenTurn.upright, ScreenTurn.topToRight);

      expect(
        transition.lagAfter(halfWay).abs(),
        closeTo(ScreenTurn.topToRight.angle / 2, 1e-9),
      );
    });

    test('swings the short way between the two sideways turns', () {
      final transition = ScreenTurnTransition()
        ..begin(ScreenTurn.upsideDown, ScreenTurn.topToLeft);

      expect(
        transition.lagAfter(Duration.zero).abs(),
        closeTo(ScreenTurn.topToRight.angle, 1e-9),
      );
    });

    test('a swing cut short carries what was left into the next', () {
      final transition = ScreenTurnTransition(
        duration: swing,
        curve: Curves.linear,
      )
        ..begin(ScreenTurn.upright, ScreenTurn.topToRight)
        ..begin(
          ScreenTurn.topToRight,
          ScreenTurn.upright,
          interruptedAfter: halfWay,
        );

      expect(
        transition.lagAfter(Duration.zero),
        closeTo(ScreenTurn.topToRight.angle / 2, 1e-9),
      );
    });

    test('finishing forgets the swing', () {
      final transition = ScreenTurnTransition()
        ..begin(ScreenTurn.upright, ScreenTurn.upsideDown)
        ..finish();

      expect(transition.isSettledAfter(Duration.zero), isTrue);
    });
  });
}
