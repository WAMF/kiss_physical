import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The colours of the light falling on physical surfaces, as linear RGB
/// multipliers.
@immutable
class LightTone {
  /// Creates a tone from its directional [key] light and its [fill] light.
  const LightTone({required this.key, required this.fill});

  /// White light from every side, which leaves surfaces at their own colours.
  static const neutral = LightTone(
    key: LightColor(1, 1, 1),
    fill: LightColor(1, 1, 1),
  );

  /// The directional light: the sun or the moon.
  final LightColor key;

  /// The light of the sky, which reaches the sides turned away from [key].
  final LightColor fill;

  @override
  bool operator ==(Object other) =>
      other is LightTone && other.key == key && other.fill == fill;

  @override
  int get hashCode => Object.hash(key, fill);
}

/// A linear RGB light intensity per channel.
@immutable
class LightColor {
  /// Creates a light colour from its intensity in each channel.
  const LightColor(this.red, this.green, this.blue);

  /// The colour a share [t] of the way from [a] to [b].
  factory LightColor.lerp(LightColor a, LightColor b, double t) => LightColor(
        lerpDouble(a.red, b.red, t)!,
        lerpDouble(a.green, b.green, t)!,
        lerpDouble(a.blue, b.blue, t)!,
      );

  /// Intensity of the red channel.
  final double red;

  /// Intensity of the green channel.
  final double green;

  /// Intensity of the blue channel.
  final double blue;

  @override
  bool operator ==(Object other) =>
      other is LightColor &&
      other.red == red &&
      other.green == green &&
      other.blue == blue;

  @override
  int get hashCode => Object.hash(red, green, blue);
}

/// Where the sun or moon stands at a moment of the day, and what colour its
/// light has after crossing the atmosphere.
///
/// The position comes from the date, the wall clock and a latitude; no
/// location or compass is used. East is taken to be the left of the screen,
/// so morning light arrives from the left and evening light from the right.
@immutable
class SkyLight {
  /// Creates a sky from where its light leans, its colours and the height of
  /// the sun.
  const SkyLight({
    required this.lean,
    required this.tone,
    required this.sunElevation,
  });

  /// The sky at [moment], read as local wall-clock time, for an observer at
  /// [latitude] degrees.
  factory SkyLight.at(DateTime moment, {double latitude = _Site.latitude}) {
    final sun = _SolarPosition.at(moment, latitude);
    final daylight = _smoothStep(
      _Twilight.end,
      _Twilight.start,
      sun.elevation,
    );
    final sunTone = _Atmosphere.sunlight(math.max(sun.elevation, 0));
    return SkyLight(
      lean: Offset(
        lerpDouble(sun.eastward, -sun.eastward, daylight)! * _Site.leanGain,
        0,
      ),
      tone: LightTone(
        key: LightColor.lerp(_Moon.key, sunTone, daylight),
        fill: LightColor.lerp(_Moon.fill, _Atmosphere.skyFill, daylight),
      ),
      sunElevation: sun.elevation,
    );
  }

  /// A white light straight overhead, which changes nothing.
  static const neutral = SkyLight(
    lean: Offset.zero,
    tone: LightTone.neutral,
    sunElevation: math.pi / 2,
  );

  /// A typical latitude for the hemisphere of [countryCode], an ISO 3166
  /// code, so the seasons fall the right way round without knowing where the
  /// device is.
  static double latitudeForCountry(String? countryCode) {
    final isSouthern = _Site.southernCountries.contains(
      countryCode?.toUpperCase(),
    );
    return isSouthern ? -_Site.latitude : _Site.latitude;
  }

  /// How far the light leans across the screen: negative x from the left.
  final Offset lean;

  /// The colours of the light from the sun or moon and from the sky.
  final LightTone tone;

  /// Angle of the sun above the horizon in radians; negative at night.
  final double sunElevation;

  /// Whether the sun is far enough below the horizon for the moon to light
  /// the scene.
  bool get isNight => sunElevation < _Twilight.end;

  @override
  bool operator ==(Object other) =>
      other is SkyLight &&
      other.lean == lean &&
      other.tone == tone &&
      other.sunElevation == sunElevation;

  @override
  int get hashCode => Object.hash(lean, tone, sunElevation);
}

class _Site {
  static const latitude = 42.0;
  static const leanGain = 0.95;

  static const southernCountries = {
    'AR', 'AU', 'BO', 'BR', 'BW', 'CL', 'FJ', 'LS', 'MG', 'MU', 'MZ', 'NA', //
    'NZ', 'PE', 'PG', 'PY', 'SZ', 'UY', 'ZA', 'ZM', 'ZW',
  };
}

class _Twilight {
  static const start = 2 * math.pi / 180;
  static const end = -6 * math.pi / 180;
}

class _Moon {
  static const key = LightColor(0.42, 0.50, 0.68);
  static const fill = LightColor(0.70, 0.80, 1);
}

/// The sun as seen from the ground.
class _SolarPosition {
  const _SolarPosition(this.elevation, this.eastward);

  factory _SolarPosition.at(DateTime moment, double latitude) {
    final dayOfYear = moment.difference(DateTime(moment.year)).inDays + 1;
    final declination = -_axialTilt *
        math.cos(2 * math.pi * (dayOfYear + _daysFromSolsticeToNewYear) / 365);
    final solarHours = moment.hour +
        moment.minute / Duration.minutesPerHour +
        moment.second / Duration.secondsPerHour -
        _daylightSaving(moment).inMinutes / Duration.minutesPerHour;
    final hourAngle = (solarHours - _noon) * _radiansPerHour;
    final phi = latitude * math.pi / 180;
    final sine = math.sin(phi) * math.sin(declination) +
        math.cos(phi) * math.cos(declination) * math.cos(hourAngle);
    return _SolarPosition(
      math.asin(sine.clamp(-1.0, 1.0)),
      -math.cos(declination) * math.sin(hourAngle),
    );
  }

  static const _axialTilt = 23.44 * math.pi / 180;
  static const _daysFromSolsticeToNewYear = 10;
  static const _noon = 12.0;
  static const _radiansPerHour = math.pi / 12;

  /// How far the clocks are ahead of standard time at [moment].
  static Duration _daylightSaving(DateTime moment) {
    if (moment.isUtc) return Duration.zero;
    final january = DateTime(moment.year).timeZoneOffset;
    final july = DateTime(moment.year, DateTime.july).timeZoneOffset;
    final standard = january < july ? january : july;
    return moment.timeZoneOffset - standard;
  }

  /// Angle above the horizon in radians.
  final double elevation;

  /// Horizontal part of the direction to the sun pointing east, from -1 to 1.
  final double eastward;
}

/// Scattering of sunlight on its way through slightly hazy air: Rayleigh
/// scattering by the air itself plus the dust and moisture that turn a low
/// sun golden and then red.
class _Atmosphere {
  /// Vertical optical depth of clean air for red, green and blue light.
  static const _air = LightColor(0.042, 0.099, 0.244);

  /// Vertical optical depth of a light haze for red, green and blue light.
  static const _haze = LightColor(0.09, 0.12, 0.16);

  /// How strongly the scattered colour shows, from 0 (always white) to 1.
  static const _tintStrength = 0.9;

  static const skyFill = LightColor(0.88, 0.94, 1);

  /// The colour of direct sunlight at [elevation] radians, relative to an
  /// overhead sun and normalised so its strongest channel is 1.
  static LightColor sunlight(double elevation) {
    final extraAir = _airMass(elevation) - 1;
    final red = math.exp(-(_air.red + _haze.red) * extraAir);
    final green = math.exp(-(_air.green + _haze.green) * extraAir);
    final blue = math.exp(-(_air.blue + _haze.blue) * extraAir);
    return LightColor.lerp(
      LightTone.neutral.key,
      LightColor(1, green / red, blue / red),
      _tintStrength,
    );
  }

  /// Kasten and Young's relative air mass along the line of sight.
  static double _airMass(double elevation) {
    final degrees = elevation * 180 / math.pi;
    final horizonTerm = _horizonScale *
        math.pow(degrees + _horizonOffsetDegrees, _horizonExponent);
    return 1 / (math.sin(elevation) + horizonTerm);
  }

  static const _horizonScale = 0.50572;
  static const _horizonOffsetDegrees = 6.07995;
  static const _horizonExponent = -1.6364;
}

double _smoothStep(double from, double to, double value) {
  final t = ((value - from) / (to - from)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
