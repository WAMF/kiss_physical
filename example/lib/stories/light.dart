import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical_example/support/stage.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

class _Sample {
  static const lightReach = 1.0;
  static const beadCount = 4;
  static const hoursShown = [6.0, 9.0, 12.0, 18.0, 20.5, 23.0];
  static const midsummer = (year: 2026, month: 6, day: 21);
  static const slabHeight = 96.0;
  static const latitude = 42.0;
}

@widgetbook.UseCase(
  name: 'A light fixed over the screen',
  type: PhysicalLight,
  path: 'Light',
)
Widget buildFixedLight(BuildContext context) {
  final direction = Offset(
    context.knobs.double.slider(
      label: 'Across',
      initialValue: PhysicalLight.still.value.dx,
      min: -_Sample.lightReach,
      max: _Sample.lightReach,
    ),
    context.knobs.double.slider(
      label: 'Down',
      initialValue: PhysicalLight.still.value.dy,
      min: -_Sample.lightReach,
      max: _Sample.lightReach,
    ),
  );
  return Stage(
    child: PhysicalLight(
      direction: AlwaysStoppedAnimation(direction),
      child: const _LitBodies(),
    ),
  );
}

@widgetbook.UseCase(
  name: 'A light that stays put as the device tilts',
  type: WorldLight,
  path: 'Light',
)
Widget buildWorldLight(BuildContext context) {
  return const Stage(
    child: WorldLight(
      child: Specimen(
        label: 'Tilt a phone or tablet to move the highlights',
        child: _LitBodies(),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Through the day',
  type: SkyLight,
  path: 'Light',
)
Widget buildSkyLight(BuildContext context) {
  return Stage(
    child: Column(
      children: [
        for (final hour in _Sample.hoursShown) _HourOfLight(hour: hour),
      ],
    ),
  );
}

/// A slab and a row of beads, lit by the nearest [PhysicalLight].
class _LitBodies extends StatelessWidget {
  const _LitBodies();

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final colors = SemanticColors.of(context).data;
    return Column(
      spacing: layout.itemSpacing.medium,
      children: [
        SizedBox(
          height: _Sample.slabHeight,
          child: PhysicalSurface(
            color: colors.secondary.background,
            borderRadius: BorderRadius.circular(layout.cornerRadii.large),
            child: const SizedBox.expand(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var bead = 0; bead < _Sample.beadCount; bead++)
              SizedBox.square(
                dimension: layout.heroSizes.small.width,
                child: PhysicalSurface(
                  color: colors.brand.primary.background,
                  material: PhysicalMaterial.bead,
                  borderRadius: PhysicalSurface.stadium,
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The lit bodies under the sun or moon of one [hour] of a midsummer day.
class _HourOfLight extends StatelessWidget {
  const _HourOfLight({required this.hour});

  final double hour;

  SkyLight get _sky {
    const day = _Sample.midsummer;
    return SkyLight.at(
      latitude: _Sample.latitude,
      DateTime(day.year, day.month, day.day).add(
        Duration(seconds: (hour * Duration.secondsPerHour).round()),
      ),
    );
  }

  String get _label {
    final wholeHour = hour.floor();
    final minutes = ((hour - wholeHour) * Duration.minutesPerHour).round();
    return '${'$wholeHour'.padLeft(2, '0')}:${'$minutes'.padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sky = _sky;
    return Specimen(
      label: sky.isNight ? '$_label · moonlight' : '$_label · sunlight',
      child: PhysicalLight(
        direction: AlwaysStoppedAnimation(PhysicalLight.still.value + sky.lean),
        tone: AlwaysStoppedAnimation(sky.tone),
        child: const _LitBodies(),
      ),
    );
  }
}
