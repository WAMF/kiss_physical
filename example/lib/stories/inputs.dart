import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical_example/support/stage.dart';
import 'package:kiss_physical_example/support/substance_knob.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

class _Sample {
  static const periods = ['Day', 'Week', 'Month', 'Year'];
  static const trackOpacity = 0.15;
  static const hint = 'Search foods';
  static const sizes = [24.0, 40.0, 64.0];
}

/// Keeps the value a control is showing, as an app would.
class _Held<T> extends StatefulWidget {
  const _Held({required this.initial, required this.builder});

  final T initial;
  final Widget Function(T value, ValueChanged<T> onChanged) builder;

  @override
  State<_Held<T>> createState() => _HeldState<T>();
}

class _HeldState<T> extends State<_Held<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return widget.builder(_value, (value) => setState(() => _value = value));
  }
}

Color _trackOf(BuildContext context) {
  final colors = SemanticColors.of(context).data;
  return colors.secondary.foreground.withValues(alpha: _Sample.trackOpacity);
}

@widgetbook.UseCase(name: 'Switch', type: PhysicalSwitch, path: 'Controls')
Widget buildSwitch(BuildContext context) {
  final colors = SemanticColors.of(context).data;
  final enabled = context.knobs.boolean(label: 'Enabled', initialValue: true);
  final bead = SubstanceKnob.of(context, part: 'Bead');
  final track = SubstanceKnob.of(context, part: 'Track');
  return Stage(
    child: Center(
      child: _Held<bool>(
        initial: false,
        builder: (value, onChanged) => PhysicalSwitch(
          value: value,
          onChanged: enabled ? onChanged : null,
          semanticLabel: 'Reminders',
          activeColor: colors.brand.primary.background,
          trackColor: _trackOf(context),
          thumbColor: colors.secondary.background,
          thumbMaterial: PhysicalMaterial.bead.withTexture(bead),
          trackMaterial: PhysicalMaterial.well.withTexture(track),
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Segmented control',
  type: PhysicalSegmentedControl,
  path: 'Controls',
)
Widget buildSegmentedControl(BuildContext context) {
  final colors = SemanticColors.of(context).data;
  final enabled = context.knobs.boolean(label: 'Enabled', initialValue: true);
  final thumb = SubstanceKnob.of(context, part: 'Thumb');
  final track = SubstanceKnob.of(context, part: 'Track');
  return Stage(
    child: _Held<String>(
      initial: _Sample.periods.first,
      builder: (value, onChanged) => PhysicalSegmentedControl<String>(
        segments: {
          for (final period in _Sample.periods) period: Text(period),
        },
        selected: value,
        onChanged: enabled ? onChanged : null,
        semanticLabel: 'Period',
        trackColor: _trackOf(context),
        thumbColor: colors.brand.primary.background,
        foregroundColor: colors.secondary.foreground,
        selectedForegroundColor: colors.brand.primary.foreground,
        thumbMaterial: PhysicalMaterial.gloss.withTexture(thumb),
        trackMaterial: PhysicalMaterial.well.withTexture(track),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Text field',
  type: PhysicalTextField,
  path: 'Controls',
)
Widget buildTextField(BuildContext context) {
  final layout = Layout.of(context);
  final colors = SemanticColors.of(context).data;
  final enabled = context.knobs.boolean(label: 'Enabled', initialValue: true);
  final material = PhysicalMaterial.well.withTexture(SubstanceKnob.of(context));
  return Stage(
    child: Column(
      spacing: layout.itemSpacing.medium,
      children: [
        PhysicalTextField(
          hintText: _Sample.hint,
          enabled: enabled,
          material: material,
          textInputAction: TextInputAction.search,
          leading: Icon(Icons.search, color: colors.secondary.foreground),
        ),
        PhysicalTextField(
          hintText: 'Notes',
          enabled: enabled,
          material: material,
          minLines: 3,
          maxLines: 5,
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(name: 'Spinner', type: PhysicalSpinner, path: 'Controls')
Widget buildSpinner(BuildContext context) {
  final layout = Layout.of(context);
  final colors = SemanticColors.of(context).data;
  final bead = SubstanceKnob.of(context, part: 'Bead');
  final dish = SubstanceKnob.of(context, part: 'Dish');
  return Stage(
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: layout.itemSpacing.large,
      children: [
        for (final size in _Sample.sizes)
          PhysicalSpinner(
            diameter: size,
            semanticLabel: 'Loading',
            beadColor: colors.brand.primary.background,
            dishColor: _trackOf(context),
            beadMaterial: PhysicalMaterial.bead.withTexture(bead),
            dishMaterial: PhysicalMaterial.well.withTexture(dish),
          ),
      ],
    ),
  );
}
