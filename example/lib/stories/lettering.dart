import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical_example/support/stage.dart';
import 'package:kiss_physical_example/support/substance_knob.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

class _Sample {
  static const words = 'Glorious 123';
  static const smallest = 16.0;
  static const largest = 96.0;
  static const startingSize = 56.0;
  static const gold = Color(0xFFD9A441);
  static const steel = Color(0xFFB8BEC6);
  static const polished = PhysicalMaterial(
    roughness: 0.22,
    specularTint: 0.9,
    elevation: 2,
  );
  static const engraved = PhysicalMaterial(
    roughness: 0.6,
    relief: -1,
    elevation: 0,
  );
}

@widgetbook.UseCase(
  name: 'Finishes',
  type: PhysicalText,
  path: 'Lettering',
)
Widget buildLettering(BuildContext context) {
  final layout = Layout.of(context);
  final colors = SemanticColors.of(context).data;
  final words = context.knobs.string(
    label: 'Words',
    initialValue: _Sample.words,
  );
  final size = context.knobs.double.slider(
    label: 'Font size',
    initialValue: _Sample.startingSize,
    min: _Sample.smallest,
    max: _Sample.largest,
  );
  final isHeavy = context.knobs.boolean(label: 'Heavy', initialValue: true);
  final accent = colors.brand.primary.background;
  final substance = PhysicalMaterial.satin.withTexture(
    SubstanceKnob.of(context),
  );
  final specimens = {
    'Substance': (accent, substance),
    'Satin': (accent, PhysicalMaterial.satin),
    'Gloss': (accent, PhysicalMaterial.gloss),
    'Gold': (_Sample.gold, _Sample.polished),
    'Steel': (_Sample.steel, _Sample.polished),
    'Engraved': (colors.secondary.background, _Sample.engraved),
  };
  return Stage(
    child: DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: size,
        fontWeight: isHeavy ? FontWeight.w900 : FontWeight.w400,
      ),
      child: Column(
        spacing: layout.itemSpacing.large,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final MapEntry(key: label, value: (color, material))
              in specimens.entries)
            Specimen(
              label: label,
              child: PhysicalText(words, color: color, material: material),
            ),
        ],
      ),
    ),
  );
}
