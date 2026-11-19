import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical_example/support/stage.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

class _Sample {
  static const sliderStart = 0.4;
  static const sliderSteps = 10;
  static const trackOpacity = 0.15;
  static const progressStart = 0.6;
  static const tilePadding = EdgeInsets.symmetric(horizontal: 24);
}

@widgetbook.UseCase(
  name: 'Pill buttons',
  type: PhysicalPillButton,
  path: 'Controls/Buttons',
)
Widget buildPillButtons(BuildContext context) {
  final layout = Layout.of(context);
  final colors = SemanticColors.of(context).data;
  final label = context.knobs.string(label: 'Label', initialValue: 'Save');
  final enabled = context.knobs.boolean(label: 'Enabled', initialValue: true);
  final onPressed = enabled ? () {} : null;
  return Stage(
    child: Wrap(
      spacing: layout.itemSpacing.medium,
      runSpacing: layout.itemSpacing.medium,
      children: [
        for (final role in [colors.brand.primary, colors.brand.secondary])
          PhysicalPillButton(
            color: role.background,
            foregroundColor: role.foreground,
            minimumSize: layout.actionSizes.medium,
            onPressed: onPressed,
            child: Text(label),
          ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Material buttons in a physical style',
  type: PhysicalButtonBackground,
  path: 'Controls/Buttons',
)
Widget buildStyledButtons(BuildContext context) {
  final layout = Layout.of(context);
  final colors = SemanticColors.of(context).data;
  final style = physicalButtonStyle(
    color: colors.brand.primary.background,
    foregroundColor: colors.brand.primary.foreground,
  );
  return Stage(
    child: Wrap(
      spacing: layout.itemSpacing.medium,
      runSpacing: layout.itemSpacing.medium,
      children: [
        FilledButton(
          style: style,
          onPressed: () {},
          child: const Text('Filled'),
        ),
        TextButton(style: style, onPressed: () {}, child: const Text('Text')),
        ElevatedButton(style: style, onPressed: null, child: const Text('Off')),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Icon buttons',
  type: PhysicalIconButton,
  path: 'Controls/Buttons',
)
Widget buildIconButtons(BuildContext context) {
  final layout = Layout.of(context);
  final colors = SemanticColors.of(context).data;
  return Stage(
    child: Wrap(
      spacing: layout.itemSpacing.medium,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final size in [layout.heroSizes.small, layout.actionSizes.large])
          PhysicalIconButton(
            diameter: size.height,
            backgroundColor: colors.brand.primary.background,
            onTap: () {},
            icon: Icon(Icons.add, color: colors.brand.primary.foreground),
          ),
        PhysicalIconButton(
          diameter: layout.heroSizes.small.height,
          onTap: () {},
          icon: Icon(Icons.check, color: colors.secondary.foreground),
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Any shape that sinks when pressed',
  type: PhysicalPressable,
  path: 'Controls/Buttons',
)
Widget buildPressable(BuildContext context) {
  final layout = Layout.of(context);
  final colors = SemanticColors.of(context).data;
  return Stage(
    child: SizedBox(
      height: layout.actionSizes.large.height,
      child: PhysicalPressable(
        onTap: () {},
        color: colors.secondary.background,
        material: PhysicalMaterial.satin,
        borderRadius: BorderRadius.circular(layout.cornerRadii.medium),
        semanticLabel: 'Open',
        child: const Padding(
          padding: _Sample.tilePadding,
          child: Row(
            children: [
              Expanded(child: Text('A pressable tile')),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Slider',
  type: PhysicalSlider,
  path: 'Controls',
)
Widget buildSlider(BuildContext context) {
  final snaps = context.knobs.boolean(label: 'Snap to ten steps');
  return Stage(
    child: _SliderDemo(divisions: snaps ? _Sample.sliderSteps : null),
  );
}

class _SliderDemo extends StatefulWidget {
  const _SliderDemo({required this.divisions});

  final int? divisions;

  @override
  State<_SliderDemo> createState() => _SliderDemoState();
}

class _SliderDemoState extends State<_SliderDemo> {
  double _value = _Sample.sliderStart;

  @override
  Widget build(BuildContext context) {
    final colors = SemanticColors.of(context).data;
    final foreground = colors.secondary.foreground;
    return PhysicalSlider(
      value: _value,
      divisions: widget.divisions,
      onChanged: (value) => setState(() => _value = value),
      barColor: colors.brand.primary.background,
      trackColor: foreground.withValues(alpha: _Sample.trackOpacity),
      thumbColor: foreground,
    );
  }
}

@widgetbook.UseCase(
  name: 'Progress bar',
  type: PhysicalProgressBar,
  path: 'Controls',
)
Widget buildProgressBar(BuildContext context) {
  final colors = SemanticColors.of(context).data;
  return Stage(
    child: PhysicalProgressBar(
      fraction: context.knobs.double.slider(
        label: 'Fraction',
        initialValue: _Sample.progressStart,
        max: 1,
      ),
      barColor: colors.brand.primary.background,
      trackColor: colors.secondary.background,
    ),
  );
}
