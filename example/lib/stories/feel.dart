import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical_example/support/stage.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

class _Sample {
  static const substances = {
    'Plastic': PhysicalTexture.plastic,
    'Oak': PhysicalTexture.oak,
    'Brass': PhysicalTexture.brass,
    'Granite': PhysicalTexture.granite,
  };
  static const startingCount = 10;
}

@widgetbook.UseCase(
  name: 'What each substance feels like to press',
  type: PhysicalFeel,
  path: 'Motion',
)
Widget buildFeel(BuildContext context) {
  final layout = Layout.of(context);
  final colors = SemanticColors.of(context).data;
  final taps = context.knobs.boolean(label: 'Haptics', initialValue: true);
  return Stage(
    child: PhysicalHaptics(
      isEnabled: taps,
      child: Wrap(
        spacing: layout.itemSpacing.large,
        runSpacing: layout.itemSpacing.large,
        children: [
          for (final MapEntry(key: name, value: texture)
              in _Sample.substances.entries)
            Specimen(
              label: name,
              child: PhysicalIconButton(
                diameter: layout.heroSizes.small.height,
                color: colors.brand.primary.background,
                material: PhysicalMaterial.bead.withTexture(texture),
                onPressed: () {},
                semanticLabel: 'Press $name',
                icon: Icon(
                  Icons.touch_app,
                  color: colors.brand.primary.foreground,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'A stepper that repeats while held',
  type: HoldRepeater,
  path: 'Motion',
)
Widget buildStepper(BuildContext context) {
  return const Stage(child: _Stepper());
}

class _Stepper extends StatefulWidget {
  const _Stepper();

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  final _count = ValueNotifier<int>(_Sample.startingCount);

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final colors = SemanticColors.of(context).data;
    final diameter = layout.actionSizes.large.height;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: layout.itemSpacing.large,
      children: [
        PhysicalIconButton(
          diameter: diameter,
          onPressed: () => _count.value--,
          repeatsWhileHeld: true,
          tooltip: 'Less',
          icon: Icon(Icons.remove, color: colors.secondary.foreground),
        ),
        ValueListenableBuilder(
          valueListenable: _count,
          builder: (context, count, _) => Text(
            '$count',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        PhysicalIconButton(
          diameter: diameter,
          onPressed: () => _count.value++,
          repeatsWhileHeld: true,
          tooltip: 'More',
          icon: Icon(Icons.add, color: colors.secondary.foreground),
        ),
      ],
    );
  }
}
