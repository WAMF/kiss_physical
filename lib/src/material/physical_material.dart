import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:kiss_physical/src/material/physical_decals.dart';
import 'package:kiss_physical/src/material/physical_effect.dart';
import 'package:kiss_physical/src/material/physical_texture.dart';
import 'package:kiss_physical/src/material/physical_vessel.dart';

/// Describes how a `PhysicalSurface` is shaped in depth and how it responds
/// to light.
@immutable
class PhysicalMaterial {
  /// Creates a material from its shape, finish, texture, decals and effects.
  const PhysicalMaterial({
    this.roughness = 0.5,
    this.specularTint = 0,
    this.bevel = 5,
    this.crown = 0.08,
    this.relief = 1,
    this.elevation = 3,
    this.texture = PhysicalTexture.none,
    this.decals = PhysicalDecals.none,
    this.vessel,
    this.effects = const [],
  })  : assert(roughness > 0 && roughness <= 1, 'roughness must be in (0, 1]'),
        assert(relief >= -1 && relief <= 1, 'relief must be in [-1, 1]');

  /// Moulded plastic slab with a soft sheen. Suited to cards and panels.
  static const satin = PhysicalMaterial();

  /// Flat, barely reflective slab that sits flush with its parent.
  static const matte = PhysicalMaterial(
    roughness: 0.8,
    bevel: 3,
    crown: 0.04,
    elevation: 0,
  );

  /// Glossy capsule domed across its whole short side, so highlights run
  /// along the body and never outline a separate face. Suited to pills and
  /// buttons.
  static const gloss = PhysicalMaterial(
    roughness: 0.32,
    bevel: double.infinity,
    crown: 0.05,
    elevation: 4,
  );

  /// Polished lens with a gently domed face and the rolled edge of [satin].
  /// Suited to glass laid over photographs.
  static const glass = PhysicalMaterial(
    roughness: 0.2,
    crown: 0.15,
    elevation: 4,
  );

  /// Fully domed, polished body with colour-tinted reflections. Suited to
  /// discs and beads.
  static const bead = PhysicalMaterial(
    roughness: 0.45,
    specularTint: 0.25,
    bevel: double.infinity,
    crown: 0,
    elevation: 5,
  );

  /// Recess pressed into the parent surface. Suited to wells and tracks.
  static const well = PhysicalMaterial(
    roughness: 0.7,
    bevel: 4,
    crown: 0,
    relief: -0.8,
    elevation: 0,
  );

  /// Recessed pill. Suited to unselected chips.
  static const socket = PhysicalMaterial(
    roughness: 0.6,
    bevel: double.infinity,
    crown: 0,
    relief: -0.45,
    elevation: 0,
  );

  /// Small round recess, pressed deep enough to read on a dark panel.
  /// Suited to the sockets of a pegboard.
  static const peg = PhysicalMaterial(
    roughness: 0.6,
    bevel: double.infinity,
    crown: 0,
    relief: -0.8,
    elevation: 0,
  );

  /// Slab that lies flush with its parent and casts no shadow. Suited to
  /// panels that sit on a background.
  static const panel = PhysicalMaterial(elevation: 0);

  /// Slab with a broad rounded edge that floats above its parent. Suited to
  /// sheets and menus raised over content.
  static const floatingPanel = PhysicalMaterial(bevel: 8, elevation: 6);

  /// Microfacet roughness: low values give tight mirror-like highlights.
  final double roughness;

  /// How much the base colour tints reflections, from 0 (plastic) to 1
  /// (metal).
  final double specularTint;

  /// Width in logical pixels of the rounded edge. Values larger than half of
  /// the shortest side dome the whole surface.
  final double bevel;

  /// Bulge of the face, as the lean of the normal at the outer edge.
  final double crown;

  /// From -1 (pressed into the parent) to 1 (raised out of it).
  final double relief;

  /// Height above the parent in logical pixels; drives the cast shadow.
  final double elevation;

  /// What the body appears to be made of.
  final PhysicalTexture texture;

  /// What has settled on top of the body.
  final PhysicalDecals decals;

  /// A special way of drawing the body: glowing, burning or made of glass.
  /// Glass the body is made of in place of its own colour and texture, or
  /// null for a solid body.
  final PhysicalVessel? vessel;

  /// What is happening to the body, at most one effect of each kind.
  final List<PhysicalEffect> effects;

  /// The effect of [kind] on the body, if it has one.
  PhysicalEffect? effectOf(PhysicalEffectKind kind) {
    for (final effect in effects) {
      if (effect.kind == kind) return effect;
    }
    return null;
  }

  /// Whether anything on the body moves, so it must repaint every frame.
  bool get isAnimated => effects.any((effect) => effect.isAnimated);

  /// How far the cast shadow can reach beyond the surface bounds.
  double get shadowReach =>
      elevation <= 0 ? 0 : elevation * _Shadow.reachPerElevation + 1;

  /// How freely water runs on the body, from 0 to 1. Drops run fast off
  /// slick plastic and polished metal; wood and stone hold them, and so
  /// does any finish that is rough or worn.
  double get slip {
    final porosity =
        (roughness * _Slip.porosityGain - _Slip.porosityFrom).clamp(0.0, 1.0);
    final grip = (porosity * _Slip.finishShare +
            texture.imperfection * _Slip.wearShare +
            _Slip.gripOf(texture))
        .clamp(0.0, 1.0);
    if (vessel != null) return 1;
    return 1 - grip * _Slip.mostGrip;
  }

  /// How readily the body burns under a flame, from 0 to 1. Wood chars and
  /// glows with embers, plastic and plain finishes blacken, stone takes on
  /// soot and metal barely marks.
  double get flammability => vessel == null ? _Scorch.of(texture) : 0;

  /// How far anything the body draws can reach beyond its bounds.
  double get paintReach => effects.fold(
        shadowReach,
        (reach, effect) => math.max(reach, effect.reach),
      );

  /// This material with the given values replaced.
  PhysicalMaterial copyWith({
    double? roughness,
    double? specularTint,
    double? bevel,
    double? crown,
    double? relief,
    double? elevation,
    PhysicalTexture? texture,
    PhysicalDecals? decals,
    PhysicalVessel? vessel,
    List<PhysicalEffect>? effects,
  }) {
    return PhysicalMaterial(
      roughness: roughness ?? this.roughness,
      specularTint: specularTint ?? this.specularTint,
      bevel: bevel ?? this.bevel,
      crown: crown ?? this.crown,
      relief: relief ?? this.relief,
      elevation: elevation ?? this.elevation,
      texture: texture ?? this.texture,
      decals: decals ?? this.decals,
      vessel: vessel ?? this.vessel,
      effects: effects ?? this.effects,
    );
  }

  /// This material made of another substance: the same shape and finish
  /// with [texture] laid over it.
  PhysicalMaterial withTexture(PhysicalTexture texture) {
    return copyWith(texture: texture);
  }

  /// This material with whatever it is made of taking [color] in place of
  /// its natural colour, so a body of it shows in the colour it is given.
  /// A plain material is returned as it is.
  PhysicalMaterial tintedTo(Color color) {
    return texture.isPlain ? this : withTexture(texture.tinted(color));
  }

  /// This material with [decals] settled on top of it.
  PhysicalMaterial withDecals(PhysicalDecals decals) {
    return copyWith(decals: decals);
  }

  /// This material made of glass.
  PhysicalMaterial withVessel(PhysicalVessel vessel) {
    return copyWith(vessel: vessel);
  }

  /// This material with [effect] happening to it as well as any it already
  /// has. An effect takes the place of one of the same kind.
  PhysicalMaterial withEffect(PhysicalEffect effect) {
    return copyWith(
      effects: [
        for (final other in effects)
          if (other.kind != effect.kind) other,
        effect,
      ],
    );
  }

  /// This material with nothing happening to it.
  PhysicalMaterial withoutEffects() => copyWith(effects: const []);

  /// The material as it looks when pushed down by [amount], where 0 is at
  /// rest and 1 is fully pressed.
  ///
  /// A press that springs back can briefly carry [amount] past either end.
  /// The body then rises a little higher than at rest, but its relief stays
  /// within the range a material allows.
  PhysicalMaterial pressed(double amount) {
    if (amount == 0) return this;
    final pressedRelief =
        lerpDouble(relief, relief * _Press.reliefScale, amount)!;
    final pressedElevation = lerpDouble(elevation, 0, amount)!;
    return copyWith(
      relief: pressedRelief.clamp(_Press.deepestRelief, _Press.highestRelief),
      elevation: math.max(pressedElevation, 0),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhysicalMaterial &&
          other.roughness == roughness &&
          other.specularTint == specularTint &&
          other.bevel == bevel &&
          other.crown == crown &&
          other.relief == relief &&
          other.elevation == elevation &&
          other.texture == texture &&
          other.decals == decals &&
          other.vessel == vessel &&
          listEquals(other.effects, effects);

  @override
  int get hashCode => Object.hash(
        roughness,
        specularTint,
        bevel,
        crown,
        relief,
        elevation,
        texture,
        decals,
        vessel,
        Object.hashAll(effects),
      );
}

class _Slip {
  static const porosityGain = 1.4;
  static const porosityFrom = 0.3;
  static const finishShare = 0.5;
  static const wearShare = 0.4;
  static const mostGrip = 0.6;

  static const _slick = 0.0;
  static const _polished = 0.1;
  static const _fibrous = 0.45;
  static const _gritty = 0.6;

  /// How much the substance itself holds water, before its finish and wear.
  static double gripOf(PhysicalTexture texture) {
    if (texture.isPlain) return _slick;
    return switch (texture.substance) {
      PhysicalSubstance.plain || PhysicalSubstance.plastic => _slick,
      PhysicalSubstance.metal || PhysicalSubstance.marble => _polished,
      PhysicalSubstance.wood => _fibrous,
      PhysicalSubstance.stone => _gritty,
    };
  }
}

class _Scorch {
  static const _tinder = 1.0;
  static const _melting = 0.7;
  static const _painted = 0.5;
  static const _sooting = 0.3;
  static const _tempering = 0.1;

  static double of(PhysicalTexture texture) {
    if (texture.isPlain) return _painted;
    return switch (texture.substance) {
      PhysicalSubstance.wood => _tinder,
      PhysicalSubstance.plastic => _melting,
      PhysicalSubstance.plain => _painted,
      PhysicalSubstance.stone || PhysicalSubstance.marble => _sooting,
      PhysicalSubstance.metal => _tempering,
    };
  }
}

class _Shadow {
  static const reachPerElevation = 3.0;
}

class _Press {
  static const deepestRelief = -1.0;
  static const highestRelief = 1.0;
  static const reliefScale = 0.55;
}
