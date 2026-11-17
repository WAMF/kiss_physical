import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/src/light/light_pacing.dart';

class _Fixture {
  static const sample = Duration(milliseconds: 33);
  static const swing = 0.02;
  static const drift = 0.0005;
  static const manySamples = 60;
}

void main() {
  test('a swung device shows every change at once', () {
    final pacing = LightPacing();

    expect(pacing.follow(_Fixture.swing, _Fixture.sample), Duration.zero);
  });

  test('a drifting device waits the longest between changes', () {
    final pacing = LightPacing();

    expect(
      pacing.follow(_Fixture.drift, _Fixture.sample),
      LightPacing.defaultLongestWait,
    );
  });

  test('the wait doubles step by step as movement dies away', () {
    final pacing = LightPacing()..follow(_Fixture.swing, _Fixture.sample);

    final waits = <Duration>[
      for (var sample = 0; sample < _Fixture.manySamples; sample++)
        pacing.follow(_Fixture.drift, _Fixture.sample),
    ];

    expect(waits.first, lessThan(LightPacing.defaultLongestWait));
    expect(waits.last, LightPacing.defaultLongestWait);
    for (var index = 1; index < waits.length; index++) {
      expect(waits[index], greaterThanOrEqualTo(waits[index - 1]));
      expect(
        waits[index] <= waits[index - 1] * 2 ||
            waits[index - 1] == Duration.zero,
        isTrue,
      );
    }
  });

  test('picks the pace straight back up when swung again', () {
    final pacing = LightPacing();
    for (var sample = 0; sample < _Fixture.manySamples; sample++) {
      pacing.follow(_Fixture.drift, _Fixture.sample);
    }

    expect(pacing.follow(_Fixture.swing, _Fixture.sample), Duration.zero);
  });
}
