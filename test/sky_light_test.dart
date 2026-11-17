import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Fixture {
  static const northern = 42.0;
  static const southern = -42.0;

  static DateTime equinox(int hour, [int minute = 0]) =>
      DateTime.utc(2026, 3, 20, hour, minute);

  static DateTime december(int hour) => DateTime.utc(2026, 12, 21, hour);
}

SkyLight _sky(DateTime moment, {double latitude = _Fixture.northern}) {
  return SkyLight.at(moment, latitude: latitude);
}

void main() {
  group('position', () {
    test('the sun is highest at midday and lower either side', () {
      final morning = _sky(_Fixture.equinox(8));
      final midday = _sky(_Fixture.equinox(12));
      final evening = _sky(_Fixture.equinox(16));

      expect(midday.sunElevation, greaterThan(morning.sunElevation));
      expect(midday.sunElevation, greaterThan(evening.sunElevation));
      expect(morning.sunElevation, closeTo(evening.sunElevation, 0.01));
    });

    test('morning light comes from the left and evening from the right', () {
      expect(_sky(_Fixture.equinox(8)).lean.dx, lessThan(0));
      expect(_sky(_Fixture.equinox(12)).lean.dx, closeTo(0, 0.01));
      expect(_sky(_Fixture.equinox(16)).lean.dx, greaterThan(0));
    });

    test('a low sun leans further than a high one', () {
      final low = _sky(_Fixture.equinox(7)).lean.dx.abs();
      final high = _sky(_Fixture.equinox(11)).lean.dx.abs();

      expect(low, greaterThan(high));
    });

    test('at night the moon rises opposite the sun', () {
      final lateEvening = _sky(_Fixture.equinox(21));

      expect(lateEvening.isNight, isTrue);
      expect(lateEvening.lean.dx, lessThan(0));
      expect(_sky(_Fixture.equinox(3)).lean.dx, greaterThan(0));
    });

    test('the seasons are reversed south of the equator', () {
      final north = _sky(_Fixture.december(17));
      final south = _sky(_Fixture.december(17), latitude: _Fixture.southern);

      expect(north.sunElevation, lessThan(0));
      expect(south.sunElevation, greaterThan(0));
    });
  });

  group('colour', () {
    test('midday light is close to white', () {
      final key = _sky(_Fixture.equinox(12)).tone.key;

      expect(key.red, 1);
      expect(key.green, greaterThan(0.95));
      expect(key.blue, greaterThan(0.9));
    });

    test('sunrise light loses blue first, then green', () {
      final key = _sky(_Fixture.equinox(6, 20)).tone.key;

      expect(key.red, greaterThan(key.green));
      expect(key.green, greaterThan(key.blue));
      expect(key.blue, lessThan(0.6));
    });

    test('moonlight is dimmer and bluer than daylight', () {
      final moon = _sky(_Fixture.equinox(0)).tone.key;

      expect(moon.blue, greaterThan(moon.red));
      expect(moon.blue, lessThan(1));
    });

    test('changes smoothly through dusk', () {
      var previous = _sky(_Fixture.equinox(17)).tone.key;
      for (var minute = 1; minute <= 120; minute++) {
        final next = _sky(
          _Fixture.equinox(17).add(Duration(minutes: minute)),
        ).tone.key;
        expect((next.green - previous.green).abs(), lessThan(0.03));
        expect((next.blue - previous.blue).abs(), lessThan(0.03));
        previous = next;
      }
    });
  });

  test('picks the hemisphere from the country', () {
    expect(SkyLight.latitudeForCountry('AU'), lessThan(0));
    expect(SkyLight.latitudeForCountry('nz'), lessThan(0));
    expect(SkyLight.latitudeForCountry('IE'), greaterThan(0));
    expect(SkyLight.latitudeForCountry(null), greaterThan(0));
  });
}
