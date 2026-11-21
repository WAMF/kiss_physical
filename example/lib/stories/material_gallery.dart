
import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical_example/support/stage.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// Stands for the galleries of ready-made physical materials in the
/// Widgetbook tree. Each shows what one layer can do; none has controls.
abstract final class MaterialGallery {}

class _Sample {
  static const wideStage = 760.0;
  static const bottle = Size(120, 220);
  static const tumbler = Size(150, 150);
  static const roomForFlames = 96.0;
}

class _Neon {
  static const cyan = Color(0xFF38E8FF);
  static const amber = Color(0xFFFFB02E);
  static const lime = Color(0xFF9DFF3D);
  static const tube = 6.0;
  static const flicker = 0.7;
}

class _Finishes {
  static const all = {
    'satin': PhysicalMaterial.satin,
    'matte': PhysicalMaterial.matte,
    'gloss': PhysicalMaterial.gloss,
    'glass': PhysicalMaterial.glass,
    'bead': PhysicalMaterial.bead,
    'well': PhysicalMaterial.well,
    'socket': PhysicalMaterial.socket,
    'peg': PhysicalMaterial.peg,
  };
}

PhysicalMaterial _slabOf(PhysicalTexture texture) {
  return PhysicalMaterial.satin.withTexture(texture);
}

Map<String, PhysicalMaterial> _slabsOf(Map<String, PhysicalTexture> textures) {
  return textures.map((name, texture) => MapEntry(name, _slabOf(texture)));
}

class _Worn {
  static final all = {
    'scratched steel': _slabOf(
      PhysicalTexture.stainlessSteel.scratched(amount: 0.9, spread: 0.2),
    ),
    'dented copper': _slabOf(PhysicalTexture.copper.dented(0.9)),
    'tarnished brass': _slabOf(PhysicalTexture.brass.aged(1)),
    'weathered oak': _slabOf(PhysicalTexture.oak.aged(0.8).imperfect(0.5)),
    'cracked marble': _slabOf(PhysicalTexture.carrara.dented(1)),
    'pitted concrete': _slabOf(PhysicalTexture.concrete.aged(0.5).dented(0.8)),
    'scuffed plastic': _slabOf(PhysicalTexture.plastic.scratched(amount: 1)),
    'battered walnut': _slabOf(PhysicalTexture.walnut.aged(0.6).imperfect(1)),
  };
}

class _Dewy {
  static final all = {
    'dew on steel': _slabOf(PhysicalTexture.stainlessSteel)
        .withDecals(const PhysicalDecals(dew: 0.8)),
    'dewy old oak': _slabOf(PhysicalTexture.oak.aged(0.7).imperfect(0.6))
        .withDecals(const PhysicalDecals(dew: 0.6)),
    'dew in cracked granite': _slabOf(PhysicalTexture.granite.dented(0.8))
        .withDecals(const PhysicalDecals(dew: 0.5)),
    'dew on slate': _slabOf(PhysicalTexture.slate.imperfect(0.5))
        .withDecals(const PhysicalDecals(dew: 0.7)),
  };
}

class _Rained {
  static const _on = {
    'granite': PhysicalTexture.granite,
    'slate': PhysicalTexture.slate,
    'concrete': PhysicalTexture.concrete,
    'travertine': PhysicalTexture.travertine,
    'carrara': PhysicalTexture.carrara,
    'nero marquina': PhysicalTexture.neroMarquina,
    'oak': PhysicalTexture.oak,
    'walnut': PhysicalTexture.walnut,
    'stainless steel': PhysicalTexture.stainlessSteel,
    'brass': PhysicalTexture.brass,
    'copper': PhysicalTexture.copper,
    'plastic': PhysicalTexture.plastic,
  };

  static final all = _on.map(
    (name, texture) => MapEntry(
      name,
      _slabOf(texture).withEffect(const PhysicalEffect.rain()),
    ),
  );
}

class _Burning {
  static const _fire = PhysicalEffect.flame();
  static const _smouldering = PhysicalEffect.flame(
    intensity: 0.7,
    height: 24,
    scorch: 0.8,
    embers: 0.9,
  );
  static const _blaze = PhysicalEffect.flame(height: 90, turbulence: 1);

  static final all = {
    'oak on fire': _slabOf(PhysicalTexture.oak).withEffect(_fire),
    'smouldering walnut':
        _slabOf(PhysicalTexture.walnut).withEffect(_smouldering),
    'blazing ash': _slabOf(PhysicalTexture.ash).withEffect(_blaze),
    'steel in the fire':
        _slabOf(PhysicalTexture.stainlessSteel).withEffect(_fire),
    'granite in the fire': _slabOf(PhysicalTexture.granite).withEffect(_fire),
    'plastic on fire': _slabOf(PhysicalTexture.plastic).withEffect(_fire),
  };
}

class _Glowing {
  static final all = {
    'pink tube': PhysicalMaterial.satin.withEffect(
      const PhysicalEffect.neon(tube: _Neon.tube),
    ),
    'cyan tube': PhysicalMaterial.satin.withEffect(
      const PhysicalEffect.neon(color: _Neon.cyan, tube: _Neon.tube),
    ),
    'amber, filled': PhysicalMaterial.satin.withEffect(
      const PhysicalEffect.neon(color: _Neon.amber),
    ),
    'lime, flickering': PhysicalMaterial.satin.withEffect(
      const PhysicalEffect.neon(
        color: _Neon.lime,
        tube: _Neon.tube,
        flicker: _Neon.flicker,
      ),
    ),
  };
}

class _Showpieces {
  static final all = {
    'storm on a slate wall': _slabOf(PhysicalTexture.slate.imperfect(0.7))
        .withEffect(const PhysicalEffect.rain(intensity: 0.9)),
    'campfire log': _slabOf(PhysicalTexture.oak.aged(0.7).imperfect(0.6))
        .withEffect(const PhysicalEffect.flame(scorch: 0.6, embers: 0.7)),
    'copper left outside': _slabOf(PhysicalTexture.copper.aged(1).dented(0.4))
        .withDecals(const PhysicalDecals(dew: 0.7)),
    'ruin at dawn': _slabOf(PhysicalTexture.travertine.aged(0.5).dented(0.9))
        .withDecals(const PhysicalDecals(dew: 0.3)),
    'workshop bench': _slabOf(
      PhysicalTexture.walnut.aged(0.4).dented(0.5).scratched(
            amount: 1,
            spread: 0.15,
            clustering: 0.9,
          ),
    ),
    'bonfire in the rain': _slabOf(PhysicalTexture.ash.aged(0.5))
        .withEffect(const PhysicalEffect.rain(intensity: 0.5))
        .withEffect(const PhysicalEffect.flame(height: 70, embers: 0.6)),
  };
}

@widgetbook.UseCase(
  name: 'Body · Finishes',
  type: MaterialGallery,
  path: 'Materials',
)
Widget buildFinishGallery(BuildContext context) {
  return const _Swatches(materials: _Finishes.all, isPill: true);
}

@widgetbook.UseCase(
  name: 'Body · Woods',
  type: MaterialGallery,
  path: 'Materials',
)
Widget buildWoodGallery(BuildContext context) {
  return _Swatches(materials: _slabsOf(PhysicalTexture.woods));
}

@widgetbook.UseCase(
  name: 'Body · Stones and marbles',
  type: MaterialGallery,
  path: 'Materials',
)
Widget buildStoneGallery(BuildContext context) {
  return _Swatches(materials: _slabsOf(PhysicalTexture.stones));
}

@widgetbook.UseCase(
  name: 'Body · Metals',
  type: MaterialGallery,
  path: 'Materials',
)
Widget buildMetalGallery(BuildContext context) {
  return _Swatches(materials: _slabsOf(PhysicalTexture.metals));
}

@widgetbook.UseCase(
  name: 'Body · Glass',
  type: MaterialGallery,
  path: 'Materials',
)
Widget buildGlassGallery(BuildContext context) {
  final accent = SemanticColors.of(context).data.brand.primary.background;
  return Stage(
    maxWidth: _Sample.wideStage,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Specimen(
          label: 'Clear glass',
          child: _Vessels(vessel: PhysicalVessel.glass()),
        ),
        Specimen(
          label: 'Glass in the accent',
          child: _Vessels(vessel: PhysicalVessel.glass(color: accent)),
        ),
        Specimen(
          label: 'Nearly solid, in the accent',
          child: _Vessels(
            vessel: PhysicalVessel.glass(color: accent, opacity: 0.8),
          ),
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Wear · Worn and aged',
  type: MaterialGallery,
  path: 'Materials',
)
Widget buildWornGallery(BuildContext context) {
  return _Swatches(materials: _Worn.all);
}

@widgetbook.UseCase(
  name: 'Decals · Dew',
  type: MaterialGallery,
  path: 'Materials',
)
Widget buildDewGallery(BuildContext context) {
  return _Swatches(materials: _Dewy.all);
}

@widgetbook.UseCase(
  name: 'Effects · Rain',
  type: MaterialGallery,
  path: 'Materials',
)
Widget buildRainGallery(BuildContext context) {
  return _Swatches(materials: _Rained.all);
}

@widgetbook.UseCase(
  name: 'Effects · Fire',
  type: MaterialGallery,
  path: 'Materials',
)
Widget buildFireGallery(BuildContext context) {
  return _Swatches(materials: _Burning.all, gap: _Sample.roomForFlames);
}

@widgetbook.UseCase(
  name: 'Effects · Neon',
  type: MaterialGallery,
  path: 'Materials',
)
Widget buildNeonGallery(BuildContext context) {
  return _Swatches(materials: _Glowing.all, isPill: true);
}

@widgetbook.UseCase(
  name: 'Showpieces',
  type: MaterialGallery,
  path: 'Materials',
)
Widget buildShowpieces(BuildContext context) {
  return _Swatches(materials: _Showpieces.all, gap: _Sample.roomForFlames);
}

/// A labelled slab of each of [materials], side by side.
class _Swatches extends StatelessWidget {
  const _Swatches({required this.materials, this.isPill = false, this.gap});

  final Map<String, PhysicalMaterial> materials;
  final bool isPill;

  /// The space between slabs, when they need more than usual.
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final spacing = gap ?? layout.itemSpacing.medium;
    return Stage(
      maxWidth: _Sample.wideStage,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: gap ?? 0),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final MapEntry(key: name, value: material)
                in materials.entries)
              _Swatch(name: name, material: material, isPill: isPill),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.material,
    required this.isPill,
  });

  final String name;
  final PhysicalMaterial material;
  final bool isPill;

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final size = isPill
        ? Size(layout.heroSizes.medium.width, layout.heroSizes.small.height)
        : Size(layout.heroSizes.large.width, layout.heroSizes.large.height);
    return Column(
      spacing: layout.itemSpacing.small,
      children: [
        SizedBox.fromSize(
          size: size,
          child: PhysicalSurface(
            color: SemanticColors.of(context).data.secondary.background,
            material: material,
            borderRadius: isPill
                ? PhysicalSurface.stadium
                : BorderRadius.circular(layout.cornerRadii.large),
            child: const SizedBox.expand(),
          ),
        ),
        Text(name),
      ],
    );
  }
}

/// A bottle, a round flask and a tube made of the same [vessel].
class _Vessels extends StatelessWidget {
  const _Vessels({required this.vessel});

  final PhysicalVessel vessel;

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final color = SemanticColors.of(context).data.secondary.background;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: layout.itemSpacing.large,
      runSpacing: layout.itemSpacing.large,
      children: [
        SizedBox.fromSize(
          size: _Sample.bottle,
          child: PhysicalSurface(
            color: color,
            material: PhysicalMaterial.glass.withVessel(vessel),
            borderRadius: BorderRadius.circular(layout.cornerRadii.large),
            child: const SizedBox.expand(),
          ),
        ),
        SizedBox.fromSize(
          size: _Sample.tumbler,
          child: PhysicalSurface(
            color: color,
            material: PhysicalMaterial.bead.withVessel(vessel),
            borderRadius: PhysicalSurface.stadium,
            child: const SizedBox.expand(),
          ),
        ),
        SizedBox(
          width: _Sample.bottle.height,
          height: layout.actionSizes.large.height,
          child: PhysicalSurface(
            color: color,
            material: PhysicalMaterial.gloss.withVessel(vessel),
            borderRadius: PhysicalSurface.stadium,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
