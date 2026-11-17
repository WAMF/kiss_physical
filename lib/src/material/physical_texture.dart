import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The kind of substance a physical body appears to be made of.
///
/// Each is drawn by the surface shader from noise alone, with no images.
enum PhysicalSubstance {
  /// The body's plain colour, with no texture.
  plain,

  /// Growth rings, pores and fibres running along the body.
  wood,

  /// Brushed or polished metal that reflects its own colour.
  metal,

  /// A faint dimpled sheen, as on moulded plastic.
  plastic,

  /// Mottled, flecked, banded or pitted stone.
  stone,

  /// Polished stone crossed by veins.
  marble,
}

/// A texture laid over a physical material: what the body is made of, and
/// how worn it is.
///
/// A texture modifies a `PhysicalMaterial` without replacing it, so any
/// shape can be made of any substance, and modifiers stack on a preset:
///
/// ```dart
/// PhysicalMaterial.satin.withTexture(
///   PhysicalTexture.walnut.aged(0.4).imperfect(0.3),
/// )
/// ```
///
/// A preset carries the natural colours of its substance. A surface made of
/// it takes [naturalColor] in place of its own colour.
@immutable
class PhysicalTexture {
  const PhysicalTexture._(
    this.substance, {
    this.naturalColor,
    this.secondColor,
    this.patinaColor,
    this.scale = 1,
    this.strength = 1,
    this.age = 0,
    this.scratches = 0,
    this.dents = 0,
    this.scratchDirection = defaultScratchDirection,
    this.scratchSpread = defaultScratchSpread,
    this.scratchClustering = defaultScratchClustering,
    double figureA = 0,
    double figureB = 0,
    double figureC = 0,
    double figureD = 0,
  })  : _figureA = figureA,
        _figureB = figureB,
        _figureC = figureC,
        _figureD = figureD,
        assert(scale > 0, 'scale must be positive'),
        assert(strength >= 0 && strength <= 1, 'strength must be in [0, 1]'),
        assert(age >= 0 && age <= 1, 'age must be in [0, 1]'),
        assert(
          scratches >= 0 && scratches <= 1,
          'scratches must be in [0, 1]',
        ),
        assert(dents >= 0 && dents <= 1, 'dents must be in [0, 1]'),
        assert(
          scratchSpread >= 0 && scratchSpread <= 1,
          'scratchSpread must be in [0, 1]',
        ),
        assert(
          scratchClustering >= 0 && scratchClustering <= 1,
          'scratchClustering must be in [0, 1]',
        );

  /// Wood with rings [ringSpacing] logical pixels apart.
  ///
  /// [waviness] bends the grain, [contrast] sets how strongly [grainColor]
  /// shows in the late wood and pores, and [cathedral] arches the rings as
  /// on a plain-sawn board, where 0 is the straight grain of a quarter-sawn
  /// one.
  const PhysicalTexture.wood({
    Color? color,
    Color? grainColor,
    Color patinaColor = _Patina.wood,
    double ringSpacing = 14,
    double waviness = 0.5,
    double contrast = 0.6,
    double cathedral = 0.4,
  }) : this._(
          PhysicalSubstance.wood,
          naturalColor: color,
          secondColor: grainColor,
          patinaColor: patinaColor,
          figureA: ringSpacing,
          figureB: waviness,
          figureC: contrast,
          figureD: cathedral,
        );

  /// Metal, [brushing] from 0 (polished) to 1 (heavily brushed), with
  /// [fineness] setting how fine the brushed lines are.
  const PhysicalTexture.metal({
    Color? color,
    Color patinaColor = _Patina.steel,
    double brushing = 1,
    double fineness = 1,
  }) : this._(
          PhysicalSubstance.metal,
          naturalColor: color,
          secondColor: color,
          patinaColor: patinaColor,
          figureA: brushing,
          figureB: fineness,
        );

  /// Moulded plastic.
  const PhysicalTexture.moulded({Color? color})
      : this._(
          PhysicalSubstance.plastic,
          naturalColor: color,
          patinaColor: _Patina.plastic,
        );

  /// Stone. [mottling], [flecks], [banding] and [pits] each run from 0 to 1
  /// and show in [markColor].
  const PhysicalTexture.stone({
    Color? color,
    Color? markColor,
    Color patinaColor = _Patina.stone,
    double mottling = 1,
    double flecks = 1,
    double banding = 0,
    double pits = 0,
  }) : this._(
          PhysicalSubstance.stone,
          naturalColor: color,
          secondColor: markColor,
          patinaColor: patinaColor,
          figureA: mottling,
          figureB: flecks,
          figureC: banding,
          figureD: pits,
        );

  /// Marble crossed by veins in [veinColor].
  ///
  /// [veining] sets how many veins there are, [sharpness] how thin they
  /// are, [turbulence] how much they wander and [clouding] how much of the
  /// vein colour drifts through the body.
  const PhysicalTexture.marble({
    Color? color,
    Color? veinColor,
    Color patinaColor = _Patina.stone,
    double veining = 1,
    double sharpness = 0.6,
    double turbulence = 1,
    double clouding = 0.5,
  }) : this._(
          PhysicalSubstance.marble,
          naturalColor: color,
          secondColor: veinColor,
          patinaColor: patinaColor,
          figureA: veining,
          figureB: sharpness,
          figureC: turbulence,
          figureD: clouding,
        );

  /// A shallow diagonal, as from things slid across a surface.
  static const defaultScratchDirection = 0.35;

  /// Scratches fanned moderately around their common direction.
  static const defaultScratchSpread = 0.5;

  /// Scratches gathered into loose groups rather than spread evenly.
  static const defaultScratchClustering = 0.6;

  /// No texture: the material as it is.
  static const none = PhysicalTexture._(PhysicalSubstance.plain);

  // Woods.

  /// American black walnut: chocolate brown with flowing, open grain.
  static const walnut = PhysicalTexture.wood(
    color: Color(0xFF6B4A32),
    grainColor: Color(0xFF2E1D12),
    ringSpacing: 16,
    waviness: 0.7,
    contrast: 0.62,
    cathedral: 0.6,
  );

  /// European oak, natural: pale straw with a strong open grain.
  static const oak = PhysicalTexture.wood(
    color: Color(0xFFC49A63),
    grainColor: Color(0xFF8A6235),
    ringSpacing: 11,
    waviness: 0.35,
    contrast: 0.5,
    cathedral: 0.5,
  );

  /// Oak darkened by fuming, as used for dark floors and joinery.
  static const smokedOak = PhysicalTexture.wood(
    color: Color(0xFF5A4634),
    grainColor: Color(0xFF2B2018),
    ringSpacing: 11,
    waviness: 0.35,
    contrast: 0.55,
    cathedral: 0.5,
  );

  /// Mahogany: deep red-brown with fine, straight, close grain.
  static const mahogany = PhysicalTexture.wood(
    color: Color(0xFF7A3520),
    grainColor: Color(0xFF3F170E),
    ringSpacing: 8,
    waviness: 0.25,
    contrast: 0.4,
    cathedral: 0.15,
  );

  /// Teak: golden brown with straight grain and dark streaks.
  static const teak = PhysicalTexture.wood(
    color: Color(0xFFA9763F),
    grainColor: Color(0xFF5C3A1C),
    ringSpacing: 10,
    waviness: 0.3,
    contrast: 0.5,
    cathedral: 0.2,
  );

  /// Rosewood: dark purple-brown with near-black streaks.
  static const rosewood = PhysicalTexture.wood(
    color: Color(0xFF5A2B25),
    grainColor: Color(0xFF1C0D0C),
    ringSpacing: 13,
    waviness: 0.8,
    contrast: 0.75,
    cathedral: 0.35,
  );

  /// Macassar ebony: near black with bold tan stripes.
  static const macassarEbony = PhysicalTexture.wood(
    color: Color(0xFF241A16),
    grainColor: Color(0xFF8A5E3A),
    ringSpacing: 12,
    waviness: 0.25,
    contrast: 0.7,
    cathedral: 0,
  );

  /// Hard maple: creamy and even, with a faint tight grain.
  static const maple = PhysicalTexture.wood(
    color: Color(0xFFE3C9A1),
    grainColor: Color(0xFFBE9A68),
    ringSpacing: 7,
    waviness: 0.3,
    contrast: 0.28,
    cathedral: 0.3,
  );

  /// Ash: pale with a bold, widely spaced grain.
  static const ash = PhysicalTexture.wood(
    color: Color(0xFFD9C19A),
    grainColor: Color(0xFF9C7B4E),
    ringSpacing: 18,
    waviness: 0.45,
    contrast: 0.55,
    cathedral: 0.7,
  );

  /// Cherry: warm reddish brown with a smooth, gentle figure.
  static const cherry = PhysicalTexture.wood(
    color: Color(0xFFA85F3C),
    grainColor: Color(0xFF6E3320),
    ringSpacing: 12,
    waviness: 0.45,
    contrast: 0.35,
    cathedral: 0.55,
  );

  /// Wenge: very dark brown with fine black lines.
  static const wenge = PhysicalTexture.wood(
    color: Color(0xFF3A2A20),
    grainColor: Color(0xFF120C09),
    ringSpacing: 6,
    waviness: 0.15,
    contrast: 0.7,
    cathedral: 0,
  );

  /// Zebrano: pale gold with strong dark stripes.
  static const zebrano = PhysicalTexture.wood(
    color: Color(0xFFCFA869),
    grainColor: Color(0xFF4E3620),
    ringSpacing: 9,
    waviness: 0.3,
    contrast: 0.85,
    cathedral: 0,
  );

  // Marbles.

  /// Carrara: white with soft, feathery grey veins.
  static const carrara = PhysicalTexture.marble(
    color: Color(0xFFECEBE8),
    veinColor: Color(0xFF8F949A),
    veining: 1.2,
    sharpness: 0.3,
    clouding: 0.7,
  );

  /// Calacatta gold: bright white with bold grey and gold veins.
  static const calacattaGold = PhysicalTexture.marble(
    color: Color(0xFFF4F1EA),
    veinColor: Color(0xFFB08A4A),
    veining: 0.7,
    sharpness: 0.55,
    turbulence: 1.3,
    clouding: 0.35,
  );

  /// Nero Marquina: black with crisp white veins.
  static const neroMarquina = PhysicalTexture.marble(
    color: Color(0xFF17171A),
    veinColor: Color(0xFFE8E6E1),
    veining: 0.9,
    sharpness: 0.85,
    turbulence: 1.2,
    clouding: 0.1,
  );

  /// Verde Alpi: deep green with pale green and white veins.
  static const verdeAlpi = PhysicalTexture.marble(
    color: Color(0xFF1F3B2E),
    veinColor: Color(0xFFA9C4B0),
    veining: 1.4,
    turbulence: 1.4,
    clouding: 0.45,
  );

  /// Emperador: rich brown with fine cream veins.
  static const emperador = PhysicalTexture.marble(
    color: Color(0xFF5B3D2A),
    veinColor: Color(0xFFD9C3A3),
    veining: 1.6,
    sharpness: 0.75,
    turbulence: 1.1,
    clouding: 0.3,
  );

  // Other stones.

  /// Travertine: warm beige with soft bands and small elongated pits.
  static const travertine = PhysicalTexture.stone(
    color: Color(0xFFD8C7A8),
    markColor: Color(0xFFA38B66),
    mottling: 0.5,
    flecks: 0,
    banding: 0.8,
    pits: 0.8,
  );

  /// Granite: grey, mottled and flecked with dark crystals.
  static const granite = PhysicalTexture.stone(
    color: Color(0xFF8F8D89),
    markColor: Color(0xFF2E2D2C),
  );

  /// Slate: dark blue-grey with a faint layered cleft.
  static const slate = PhysicalTexture.stone(
    color: Color(0xFF3B4046),
    markColor: Color(0xFF23272B),
    mottling: 0.7,
    flecks: 0.1,
    banding: 0.5,
  );

  /// Concrete: pale grey, softly mottled, with small air holes.
  static const concrete = PhysicalTexture.stone(
    color: Color(0xFFA8A6A1),
    markColor: Color(0xFF6F6D69),
    mottling: 0.8,
    flecks: 0.15,
    pits: 0.35,
  );

  // Metals.

  /// Brushed brass, which tarnishes to verdigris.
  static const brass = PhysicalTexture.metal(
    color: Color(0xFFC9A24F),
    patinaColor: _Patina.verdigris,
  );

  /// Dark bronze with a soft brushing.
  static const bronze = PhysicalTexture.metal(
    color: Color(0xFF7A5A3A),
    patinaColor: _Patina.verdigris,
    brushing: 0.7,
  );

  /// Copper, bright and lightly brushed.
  static const copper = PhysicalTexture.metal(
    color: Color(0xFFC1744A),
    patinaColor: _Patina.verdigris,
    brushing: 0.6,
  );

  /// Brushed stainless steel.
  static const stainlessSteel = PhysicalTexture.metal(
    color: Color(0xFFB9BDC4),
    patinaColor: _Patina.tarnish,
  );

  /// Blackened steel, as used for frames and hardware.
  static const blackenedSteel = PhysicalTexture.metal(
    color: Color(0xFF34363A),
    brushing: 0.5,
  );

  /// Polished nickel: a warm mirror finish.
  static const polishedNickel = PhysicalTexture.metal(
    color: Color(0xFFCFCBC2),
    patinaColor: _Patina.tarnish,
    brushing: 0,
  );

  /// Moulded plastic in the surface's own colour.
  static const plastic = PhysicalTexture.moulded();

  /// The wood presets by name.
  static const woods = {
    'walnut': walnut,
    'oak': oak,
    'smoked oak': smokedOak,
    'mahogany': mahogany,
    'teak': teak,
    'rosewood': rosewood,
    'macassar ebony': macassarEbony,
    'maple': maple,
    'ash': ash,
    'cherry': cherry,
    'wenge': wenge,
    'zebrano': zebrano,
  };

  /// The marble and other stone presets by name.
  static const stones = {
    'carrara': carrara,
    'calacatta gold': calacattaGold,
    'nero marquina': neroMarquina,
    'verde alpi': verdeAlpi,
    'emperador': emperador,
    'travertine': travertine,
    'granite': granite,
    'slate': slate,
    'concrete': concrete,
  };

  /// The metal presets by name.
  static const metals = {
    'brass': brass,
    'bronze': bronze,
    'copper': copper,
    'stainless steel': stainlessSteel,
    'blackened steel': blackenedSteel,
    'polished nickel': polishedNickel,
  };

  /// What the body is made of.
  final PhysicalSubstance substance;

  /// The colour of the substance itself, or null to take the colour of the
  /// surface it is laid over.
  final Color? naturalColor;

  /// The colour of the grain, veins or flecks, or null for a darker shade
  /// of the body's colour.
  final Color? secondColor;

  /// The colour the surface stains or tarnishes towards as it ages.
  final Color? patinaColor;

  /// Size of the texture's features: 2 draws them twice as large.
  final double scale;

  /// How strongly the texture shows, from 0 (not at all) to 1.
  final double strength;

  /// How far the surface has aged, from 0 (new) to 1: stained or tarnished
  /// towards [patinaColor] and dulled.
  final double age;

  /// How much rubbing and dragging have marked the surface, from 0 (none)
  /// to 1: scratches, gouges and scuffed patches.
  final double scratches;

  /// How much knocks have marked the surface, from 0 (none) to 1: dents,
  /// pits, chipped edges and cracks.
  final double dents;

  /// How marked the surface is by either, from 0 (flawless) to 1.
  double get imperfection => math.max(scratches, dents);

  /// The angle in radians, clockwise from the body's long axis, that most
  /// scratches run at: the way things are habitually dragged across it.
  final double scratchDirection;

  /// How far other scratches stray from [scratchDirection], from 0 (all
  /// parallel) to 1 (some at right angles).
  final double scratchSpread;

  /// How much scratches gather into patches where damage happened, from 0
  /// (spread evenly) to 1 (in tight clusters with clear areas between).
  final double scratchClustering;

  final double _figureA;
  final double _figureB;
  final double _figureC;
  final double _figureD;

  /// The four numbers shaping this texture, in the order its shader reads
  /// them.
  List<double> get figure => [_figureA, _figureB, _figureC, _figureD];

  /// Whether there is no texture to draw.
  bool get isPlain => substance == PhysicalSubstance.plain || strength == 0;

  /// The colour of the grain, veins or flecks on a body coloured [body].
  Color secondColorOn(Color body) {
    return secondColor ?? Color.lerp(body, _Shade.dark, _Shade.grainDarkening)!;
  }

  /// The colour a body coloured [body] ages towards.
  Color patinaColorOn(Color body) {
    return patinaColor ?? Color.lerp(body, _Shade.dark, _Shade.ageDarkening)!;
  }

  /// This texture aged by [amount], from 0 (new) to 1.
  PhysicalTexture aged(double amount) => _copyWith(age: amount);

  /// This texture marked with scratches and dents alike by [amount], from 0
  /// (flawless) to 1.
  PhysicalTexture imperfect(double amount) {
    return _copyWith(scratches: amount, dents: amount);
  }

  /// This texture dented, pitted, chipped and cracked by [amount], from 0
  /// (not at all) to 1, leaving its scratches as they are.
  PhysicalTexture dented(double amount) => _copyWith(dents: amount);

  /// This texture with different scratches: the [amount] of them from 0
  /// (none) to 1, the [direction] most of them run in, how far others
  /// [spread] from it, and how much they gather through [clustering]. Each
  /// keeps its value when omitted, and its dents stay as they are.
  PhysicalTexture scratched({
    double? amount,
    double? direction,
    double? spread,
    double? clustering,
  }) {
    return _copyWith(
      scratches: amount,
      scratchDirection: direction,
      scratchSpread: spread,
      scratchClustering: clustering,
    );
  }

  /// This texture with its features [factor] times their natural size.
  PhysicalTexture scaled(double factor) => _copyWith(scale: factor);

  /// This texture showing at [amount] of its full strength.
  PhysicalTexture faded(double amount) => _copyWith(strength: amount);

  /// This texture on a body coloured [color], in place of its natural
  /// colour.
  PhysicalTexture tinted(Color color) {
    return PhysicalTexture._(
      substance,
      naturalColor: color,
      secondColor: substance == PhysicalSubstance.metal ? color : secondColor,
      patinaColor: patinaColor,
      scale: scale,
      strength: strength,
      age: age,
      scratches: scratches,
      dents: dents,
      scratchDirection: scratchDirection,
      scratchSpread: scratchSpread,
      scratchClustering: scratchClustering,
      figureA: _figureA,
      figureB: _figureB,
      figureC: _figureC,
      figureD: _figureD,
    );
  }

  PhysicalTexture _copyWith({
    double? scale,
    double? strength,
    double? age,
    double? scratches,
    double? dents,
    double? scratchDirection,
    double? scratchSpread,
    double? scratchClustering,
  }) {
    return PhysicalTexture._(
      substance,
      naturalColor: naturalColor,
      secondColor: secondColor,
      patinaColor: patinaColor,
      scale: scale ?? this.scale,
      strength: strength ?? this.strength,
      age: age ?? this.age,
      scratches: scratches ?? this.scratches,
      dents: dents ?? this.dents,
      scratchDirection: scratchDirection ?? this.scratchDirection,
      scratchSpread: scratchSpread ?? this.scratchSpread,
      scratchClustering: scratchClustering ?? this.scratchClustering,
      figureA: _figureA,
      figureB: _figureB,
      figureC: _figureC,
      figureD: _figureD,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhysicalTexture &&
          other.substance == substance &&
          other.naturalColor == naturalColor &&
          other.secondColor == secondColor &&
          other.patinaColor == patinaColor &&
          other.scale == scale &&
          other.strength == strength &&
          other.age == age &&
          other.scratches == scratches &&
          other.dents == dents &&
          other.scratchDirection == scratchDirection &&
          other.scratchSpread == scratchSpread &&
          other.scratchClustering == scratchClustering &&
          listEquals(other.figure, figure);

  @override
  int get hashCode => Object.hash(
        substance,
        naturalColor,
        secondColor,
        patinaColor,
        scale,
        strength,
        age,
        scratches,
        dents,
        scratchDirection,
        scratchSpread,
        scratchClustering,
        Object.hashAll(figure),
      );
}

/// What each kind of substance ages towards.
class _Patina {
  static const wood = Color(0xFF3A2A1C);
  static const stone = Color(0xFF8A7A5A);
  static const plastic = Color(0xFFC9B37A);
  static const steel = Color(0xFF7A3E22);
  static const tarnish = Color(0xFF5E5A52);
  static const verdigris = Color(0xFF4E8F7A);
}

class _Shade {
  static const dark = Color(0xFF000000);
  static const grainDarkening = 0.55;
  static const ageDarkening = 0.4;
}
