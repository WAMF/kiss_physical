import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical_example/support/device_tilt.dart';
import 'package:kiss_physical_example/support/knob_section.dart';
import 'package:kiss_physical_example/support/stage.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// Stands for the one place every layer of a physical material can be set
/// in the Widgetbook tree.
abstract final class MaterialPlayground {}

class _Sample {
  static const custom = 'custom (sliders below)';
  static const finishes = {
    'satin': PhysicalMaterial.satin,
    'matte': PhysicalMaterial.matte,
    'gloss': PhysicalMaterial.gloss,
    'bead': PhysicalMaterial.bead,
    'well': PhysicalMaterial.well,
    'socket': PhysicalMaterial.socket,
    'peg': PhysicalMaterial.peg,
  };

  static const textures = {
    'plain': PhysicalTexture.none,
    ...PhysicalTexture.stones,
    ...PhysicalTexture.woods,
    ...PhysicalTexture.metals,
    'plastic': PhysicalTexture.plastic,
  };

  static const startingTexture = 'granite';
  static const solid = 'solid';
  static const glass = 'glass';
  static const vessels = [solid, glass];

  static const wideStage = 760.0;
  static const slabHeight = 420.0;
  static const leastRoughness = 0.05;
  static const maxBevel = 40.0;
  static const maxCrown = 0.5;
  static const maxElevation = 12.0;
  static const leastScale = 0.25;
  static const maxScale = 4.0;
  static const scratchDegrees = 20.0;
  static const fullTurnDegrees = 360.0;
  static const halfTurnDegrees = 180.0;
  static const maxFlameHeight = 140.0;
  static const tubeWidth = 6.0;
  static const maxTubeWidth = 16.0;
  static const neonPink = Color(0xFFFF3D9A);
}

/// The shape and sheen of the body before anything is laid on it.
class _ShapeKnobs {
  _ShapeKnobs(BuildContext context)
      : finish = context.knobs.object.dropdown<String>(
          label: 'Finish',
          options: [..._Sample.finishes.keys, _Sample.custom],
        ),
        roughness = context.knobs.double.slider(
          label: 'Custom roughness',
          initialValue: PhysicalMaterial.satin.roughness,
          min: _Sample.leastRoughness,
          max: 1,
        ),
        bevel = context.knobs.double.slider(
          label: 'Custom bevel',
          initialValue: PhysicalMaterial.satin.bevel,
          max: _Sample.maxBevel,
        ),
        crown = context.knobs.double.slider(
          label: 'Custom crown',
          initialValue: PhysicalMaterial.satin.crown,
          max: _Sample.maxCrown,
        ),
        relief = context.knobs.double.slider(
          label: 'Custom relief',
          initialValue: 1,
          min: -1,
          max: 1,
        ),
        elevation = context.knobs.double.slider(
          label: 'Custom elevation',
          initialValue: PhysicalMaterial.satin.elevation,
          max: _Sample.maxElevation,
        ),
        inAccent = context.knobs.boolean(label: 'Body in the accent colour');

  final String finish;
  final double roughness;
  final double bevel;
  final double crown;
  final double relief;
  final double elevation;
  final bool inAccent;

  PhysicalMaterial get material {
    return _Sample.finishes[finish] ??
        PhysicalMaterial(
          roughness: roughness,
          bevel: bevel,
          crown: crown,
          relief: relief,
          elevation: elevation,
        );
  }
}

/// Layer 1, the body: what it is made of, and whether it is solid.
class _BodyKnobs {
  _BodyKnobs(BuildContext context)
      : texture = context.knobs.object.dropdown<String>(
          label: 'Made of',
          options: _Sample.textures.keys.toList(),
          initialOption: _Sample.startingTexture,
        ),
        scale = context.knobs.double.slider(
          label: 'Texture scale',
          initialValue: 1,
          min: _Sample.leastScale,
          max: _Sample.maxScale,
        ),
        strength = context.knobs.double.slider(
          label: 'Texture strength',
          initialValue: 1,
          max: 1,
        ),
        isTinted = context.knobs.boolean(label: 'Tint texture with the accent'),
        vessel = context.knobs.object.dropdown<String>(
          label: 'Solid or glass',
          options: _Sample.vessels,
        ),
        glassOpacity = context.knobs.double.slider(
          label: 'Glass opacity',
          initialValue: const PhysicalVessel.glass().opacity,
          max: 1,
        ),
        isVesselTinted = context.knobs.boolean(label: 'Glass in the accent');

  final String texture;
  final double scale;
  final double strength;
  final bool isTinted;
  final String vessel;
  final double glassOpacity;
  final bool isVesselTinted;

  PhysicalTexture textureOn(Color accent) {
    final made = _Sample.textures[texture]!.scaled(scale).faded(strength);
    return isTinted ? made.tinted(accent) : made;
  }

  PhysicalMaterial dress(PhysicalMaterial material, {required Color accent}) {
    if (vessel != _Sample.glass) return material;
    return material.withVessel(
      PhysicalVessel.glass(
        color: isVesselTinted ? accent : const PhysicalVessel.glass().color,
        opacity: glassOpacity,
      ),
    );
  }
}

/// Layer 2, wear: how old, how scratched and how dented the body is.
class _WearKnobs {
  _WearKnobs(BuildContext context)
      : age = context.knobs.double.slider(label: 'Age', max: 1),
        scratches = context.knobs.double.slider(label: 'Scratches', max: 1),
        dents = context.knobs.double.slider(label: 'Dents', max: 1),
        scratchDegrees = context.knobs.double.slider(
          label: 'Scratch direction (degrees)',
          initialValue: _Sample.scratchDegrees,
          max: _Sample.halfTurnDegrees,
        ),
        scratchSpread = context.knobs.double.slider(
          label: 'Scratch spread',
          initialValue: PhysicalTexture.defaultScratchSpread,
          max: 1,
        ),
        scratchClustering = context.knobs.double.slider(
          label: 'Scratch clustering',
          initialValue: PhysicalTexture.defaultScratchClustering,
          max: 1,
        );

  final double age;
  final double scratches;
  final double dents;
  final double scratchDegrees;
  final double scratchSpread;
  final double scratchClustering;

  PhysicalTexture wear(PhysicalTexture texture) {
    return texture.aged(age).dented(dents).scratched(
          amount: scratches,
          direction: scratchDegrees * math.pi / _Sample.halfTurnDegrees,
          spread: scratchSpread,
          clustering: scratchClustering,
        );
  }
}

/// Layer 3, decals: what has settled on the body and stays put.
class _DecalKnobs {
  _DecalKnobs(BuildContext context)
      : dew = context.knobs.double.slider(label: 'Dew', max: 1);

  final double dew;

  PhysicalDecals decals({required bool showHints}) {
    return PhysicalDecals(dew: dew, showHints: showHints);
  }
}

/// Layer 4, effects: what is happening to the body now. Rain and fire can
/// run together; neon replaces the body and everything on it.
class _EffectKnobs {
  _EffectKnobs(BuildContext context)
      : rain = context.knobs.double.slider(label: 'Rain', max: 1),
        isBurning = context.knobs.boolean(label: 'Fire'),
        fireIntensity = context.knobs.double.slider(
          label: 'Fire intensity',
          initialValue: const PhysicalEffect.flame().intensity,
          max: 1,
        ),
        flameHeight = context.knobs.double.slider(
          label: 'Fire height',
          initialValue: const PhysicalEffect.flame().height,
          max: _Sample.maxFlameHeight,
        ),
        turbulence = context.knobs.double.slider(
          label: 'Fire turbulence',
          initialValue: const PhysicalEffect.flame().turbulence,
          max: 1,
        ),
        scorch = context.knobs.double.slider(
          label: 'Fire scorch',
          initialValue: const PhysicalEffect.flame().scorch,
          max: 1,
        ),
        embers = context.knobs.double.slider(
          label: 'Fire embers',
          initialValue: const PhysicalEffect.flame().embers,
          max: 1,
        ),
        isGlowing = context.knobs.boolean(label: 'Neon'),
        neonInAccent = context.knobs.boolean(label: 'Neon in the accent'),
        tube = context.knobs.double.slider(
          label: 'Neon tube width (0 fills the body)',
          initialValue: _Sample.tubeWidth,
          max: _Sample.maxTubeWidth,
        ),
        flicker = context.knobs.double.slider(label: 'Neon flicker', max: 1);

  final double rain;
  final bool isBurning;
  final double fireIntensity;
  final double flameHeight;
  final double turbulence;
  final double scorch;
  final double embers;
  final bool isGlowing;
  final bool neonInAccent;
  final double tube;
  final double flicker;

  PhysicalMaterial dress(
    PhysicalMaterial material,
    _WorldKnobs world, {
    required Color accent,
  }) {
    var dressed = material;
    if (rain > 0) {
      dressed = dressed.withEffect(
        PhysicalEffect.rain(intensity: rain, gravity: world.pull),
      );
    }
    if (isBurning) {
      dressed = dressed.withEffect(
        PhysicalEffect.flame(
          intensity: fireIntensity,
          height: flameHeight,
          turbulence: turbulence,
          scorch: scorch,
          embers: embers,
          gravity: world.down,
        ),
      );
    }
    if (isGlowing) {
      dressed = dressed.withEffect(
        PhysicalEffect.neon(
          color: neonInAccent ? accent : _Sample.neonPink,
          tube: tube,
          flicker: flicker,
        ),
      );
    }
    return dressed;
  }
}

/// The world the body is in: which way is down, and a view of the hints
/// the layers pass to each other.
class _WorldKnobs {
  _WorldKnobs(BuildContext context)
      : followsDevice = DeviceTilt.knob(context),
        degrees = context.knobs.double.slider(
          label: 'Down is at (degrees)',
          max: _Sample.fullTurnDegrees,
        ),
        strength = context.knobs.double.slider(
          label: 'Gravity pull (0 lies flat)',
          initialValue: 1,
          max: 1,
        ),
        showHints = context.knobs.boolean(label: 'Show the hint map');

  final bool followsDevice;
  final double degrees;
  final double strength;
  final bool showHints;

  /// Which way is down on the screen, as a unit vector, or null to follow
  /// the device as it is tilted.
  Offset? get down {
    if (followsDevice) return null;
    final turn = degrees * math.pi / _Sample.halfTurnDegrees;
    return Offset(-math.sin(turn), math.cos(turn));
  }

  /// [down] at the strength it pulls, or null to follow the device.
  Offset? get pull {
    final direction = down;
    return direction == null ? null : direction * strength;
  }
}

@widgetbook.UseCase(
  name: 'Playground',
  type: MaterialPlayground,
  path: 'Materials',
)
Widget buildMaterialPlayground(BuildContext context) {
  final layout = Layout.of(context);
  final colors = SemanticColors.of(context).data;
  final accent = colors.brand.primary.background;

  KnobSection.start(context, 'Shape');
  final shape = _ShapeKnobs(context);
  KnobSection.start(context, '1 Body');
  final body = _BodyKnobs(context);
  KnobSection.start(context, '2 Wear');
  final wear = _WearKnobs(context);
  KnobSection.start(context, '3 Decals');
  final settled = _DecalKnobs(context);
  KnobSection.start(context, '4 Effects');
  final effects = _EffectKnobs(context);
  KnobSection.start(context, 'World');
  final world = _WorldKnobs(context);

  final color = shape.inAccent ? accent : colors.secondary.background;
  final texture = wear.wear(body.textureOn(accent));
  final decals = settled.decals(showHints: world.showHints);

  PhysicalMaterial layered(PhysicalMaterial finish) {
    final settledOn = finish.withTexture(texture).withDecals(decals);
    return effects.dress(
      body.dress(settledOn, accent: accent),
      world,
      accent: accent,
    );
  }

  return Stage(
    maxWidth: _Sample.wideStage,
    child: Column(
      spacing: layout.itemSpacing.large,
      children: [
        SizedBox(
          height: _Sample.slabHeight,
          child: PhysicalSurface(
            color: color,
            material: layered(shape.material),
            borderRadius: BorderRadius.circular(layout.cornerRadii.large),
            child: const SizedBox.expand(),
          ),
        ),
        Row(
          spacing: layout.itemSpacing.medium,
          children: [
            Expanded(
              child: SizedBox(
                height: layout.actionSizes.large.height,
                child: PhysicalPressable(
                  onTap: () {},
                  color: color,
                  material: layered(PhysicalMaterial.gloss),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            SizedBox.square(
              dimension: layout.heroSizes.small.width,
              child: PhysicalPressable(
                onTap: () {},
                color: color,
                material: layered(PhysicalMaterial.bead),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
