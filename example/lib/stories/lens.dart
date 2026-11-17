import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical_example/support/stage.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

class _Sample {
  static const maxRefraction = 2.0;
  static const maxRimWidth = 60.0;
  static const lensSize = 180.0;
  static const backdrop = Size(340, 420);
  static const backdropColumns = 4;
  static const backdropIconSize = 44.0;
  static const backdropColors = [
    Color(0xFF7FD6E8),
    Color(0xFF2E6FD6),
    Color(0xFF1B1F6B),
  ];
  static const backdropIconColors = [
    Color(0xFFFFFFFF),
    Color(0xFFFFD54A),
    Color(0xFFFF6B6B),
    Color(0xFF7CF29A),
  ];
  static const backdropIcons = [
    Icons.wb_sunny,
    Icons.nightlight,
    Icons.cloud,
    Icons.bolt,
    Icons.water_drop,
    Icons.local_fire_department,
    Icons.park,
    Icons.landscape,
    Icons.waves,
    Icons.ac_unit,
    Icons.diamond,
    Icons.palette,
    Icons.lightbulb,
    Icons.explore,
    Icons.music_note,
    Icons.rocket_launch,
    Icons.anchor,
    Icons.spa,
    Icons.favorite,
    Icons.star,
  ];
}

@widgetbook.UseCase(
  name: 'Refracting glass',
  type: PhysicalLens,
  path: 'Surfaces/Glass',
)
Widget buildLens(BuildContext context) {
  final layout = Layout.of(context);
  final accent = SemanticColors.of(context).data.brand.primary.background;
  final optics = LensOptics(
    refraction: context.knobs.double.slider(
      label: 'Refraction',
      initialValue: const LensOptics().refraction,
      max: _Sample.maxRefraction,
    ),
    rimWidth: context.knobs.double.slider(
      label: 'Rim width',
      initialValue: const LensOptics().rimWidth,
      min: 1,
      max: _Sample.maxRimWidth,
    ),
    aberration: context.knobs.double.slider(
      label: 'Aberration',
      initialValue: const LensOptics().aberration,
      max: 1,
    ),
    tint: accent,
    tintStrength: context.knobs.double.slider(
      label: 'Accent tint',
      max: 1,
    ),
  );
  return Stage(
    child: Stack(
      alignment: Alignment.center,
      children: [
        const _LensBackdrop(),
        SizedBox.square(
          dimension: _Sample.lensSize,
          child: PhysicalLens(
            optics: optics,
            borderRadius: BorderRadius.circular(layout.cornerRadii.large * 2),
            child: const OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: _LensBackdrop(),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Something busy to look at through the glass.
class _LensBackdrop extends StatelessWidget {
  const _LensBackdrop();

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    return Container(
      width: _Sample.backdrop.width,
      height: _Sample.backdrop.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(layout.cornerRadii.large),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _Sample.backdropColors,
        ),
      ),
      padding: layout.edgeSpacing.outer.medium,
      child: GridView.count(
        crossAxisCount: _Sample.backdropColumns,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final (index, icon) in _Sample.backdropIcons.indexed)
            Icon(
              icon,
              size: _Sample.backdropIconSize,
              color: _Sample.backdropIconColors[
                  index % _Sample.backdropIconColors.length],
            ),
        ],
      ),
    );
  }
}
