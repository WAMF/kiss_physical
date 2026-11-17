import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The kinds of thing that can be happening to a physical body.
enum PhysicalEffectKind {
  /// The body glows as a tube of gas with a halo around it.
  neon,

  /// The body is ringed with fire, with flames rising off its edge.
  flame,

  /// Rain is falling on the body and running down it.
  rain,
}

/// Something happening to a physical body as it is watched: it glows, it
/// burns, or rain falls on it.
///
/// Effects are the last of a body's layers and the only ones that move.
/// What the body is made of, how worn it is and what has grown on it are
/// worked out once and kept; effects are worked out afresh every frame on
/// top of them. A body can carry several at once, one of each kind:
///
/// ```dart
/// PhysicalMaterial.satin
///     .withTexture(PhysicalTexture.oak)
///     .withEffect(const PhysicalEffect.flame())
///     .withEffect(const PhysicalEffect.rain())
/// ```
///
/// Fire and rain act on the body beneath them and keep its colour. Neon
/// replaces it: a glowing body shows no texture, growth, fire or rain.
@immutable
class PhysicalEffect {
  const PhysicalEffect._(
    this.kind, {
    this.color = _Glow.none,
    this.intensity = 1,
    this.tube = 0,
    this.flicker = 0,
    this.turbulence = 0,
    this.height = 0,
    this.scorch = 0,
    this.embers = 0,
    this.gravity,
  })  : assert(
          intensity >= 0 && intensity <= 1,
          'intensity must be in [0, 1]',
        ),
        assert(tube >= 0, 'tube must not be negative'),
        assert(flicker >= 0 && flicker <= 1, 'flicker must be in [0, 1]'),
        assert(
          turbulence >= 0 && turbulence <= 1,
          'turbulence must be in [0, 1]',
        ),
        assert(height >= 0, 'height must not be negative'),
        assert(scorch >= 0 && scorch <= 1, 'scorch must be in [0, 1]'),
        assert(embers >= 0 && embers <= 1, 'embers must be in [0, 1]');

  /// A glowing tube in [color], from dark at an [intensity] of 0 to full
  /// glow at 1.
  ///
  /// With a [tube] width in logical pixels the glow is a tube bent round
  /// the outline, as on a neon sign, and the middle is left open. At 0 the
  /// whole body glows. [flicker] makes it hum and stutter like a worn
  /// tube.
  const PhysicalEffect.neon({
    Color color = _Glow.neon,
    double intensity = 1,
    double tube = 0,
    double flicker = 0,
  }) : this._(
          PhysicalEffectKind.neon,
          color: color,
          intensity: intensity,
          tube: tube,
          flicker: flicker,
        );

  /// Fire in [color] round the edge of a body, which keeps its own colour.
  /// Flames rise up to [height] logical pixels off the outline against
  /// [gravity]. [turbulence] sets how much they roll and tear, from the
  /// steady flame of a candle at 0 to a wind-blown fire at 1.
  ///
  /// What the fire does to the body is set apart from how tall it burns.
  /// [scorch] is how far in from the edge it has charred, from untouched at
  /// 0 to deeply burnt at 1, and [embers] is how much of that char glows,
  /// from none at 0. How readily the body takes either depends on what it
  /// is made of: wood chars and glows, metal barely marks.
  const PhysicalEffect.flame({
    Color color = _Glow.fire,
    double intensity = 1,
    double height = _Glow.flameHeight,
    double turbulence = _Glow.turbulence,
    double scorch = _Glow.scorch,
    double embers = _Glow.embers,
    Offset? gravity,
  }) : this._(
          PhysicalEffectKind.flame,
          color: color,
          intensity: intensity,
          height: height,
          turbulence: turbulence,
          scorch: scorch,
          embers: embers,
          gravity: gravity,
        );

  /// Rain falling on a body, from a drizzle at a low [intensity] to a
  /// downpour at 1. Drops land, bead, gather and run the way [gravity]
  /// pulls, faster off a slick body than one that grips, and what is left
  /// of them dries away after the rain stops.
  const PhysicalEffect.rain({
    double intensity = _Glow.rain,
    Offset? gravity,
  }) : this._(
          PhysicalEffectKind.rain,
          intensity: intensity,
          gravity: gravity,
        );

  /// What kind of effect this is; a body carries at most one of each kind.
  final PhysicalEffectKind kind;

  /// The colour of the glow or the fire.
  final Color color;

  /// How strong the effect is, from 0 to 1.
  final double intensity;

  /// The width of a neon tube bent round the outline, or 0 to fill the
  /// body.
  final double tube;

  /// How much a neon tube stutters, from 0 to 1.
  final double flicker;

  /// How much flames roll and tear, from 0 to 1.
  final double turbulence;

  /// How far flames rise off the body, in logical pixels.
  final double height;

  /// How far in from its edge a fire has charred the body, from 0 to 1.
  final double scorch;

  /// How much of the char glows with embers, from 0 to 1.
  final double embers;

  /// How deep the char set by [scorch] reaches, in logical pixels.
  double get scorchDepth => scorch * _Glow.deepestScorch;

  /// Which way is down for flames and rain, within the plane of the screen.
  /// For rain its length, from 0 to 1, is how strongly drops run: zero is a
  /// body lying flat, where they stay put. Left null, both follow the real
  /// world's gravity as the device is tilted, taken from the nearest
  /// `PhysicalLight`.
  final Offset? gravity;

  /// Whether the effect moves, so the surface must repaint every frame.
  bool get isAnimated => switch (kind) {
        PhysicalEffectKind.neon => flicker > 0,
        PhysicalEffectKind.flame => true,
        PhysicalEffectKind.rain => intensity > 0,
      };

  /// How far beyond the body's bounds the effect draws.
  double get reach => switch (kind) {
        PhysicalEffectKind.neon => _Glow.haloReach,
        PhysicalEffectKind.flame => height * _Glow.sparkHeadroom,
        PhysicalEffectKind.rain => 0,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhysicalEffect &&
          other.kind == kind &&
          other.color == color &&
          other.intensity == intensity &&
          other.tube == tube &&
          other.flicker == flicker &&
          other.turbulence == turbulence &&
          other.height == height &&
          other.scorch == scorch &&
          other.embers == embers &&
          other.gravity == gravity;

  @override
  int get hashCode => Object.hash(
        kind,
        color,
        intensity,
        tube,
        flicker,
        turbulence,
        height,
        scorch,
        embers,
        gravity,
      );
}

class _Glow {
  static const none = Color(0x00000000);
  static const neon = Color(0xFFFF3D9A);
  static const fire = Color(0xFFFF7A1A);
  static const flameHeight = 52.0;
  static const turbulence = 0.7;
  static const scorch = 0.3;
  static const embers = 0.3;
  static const deepestScorch = 70.0;
  static const haloReach = 48.0;
  static const sparkHeadroom = 1.5;
  static const rain = 0.6;
}
