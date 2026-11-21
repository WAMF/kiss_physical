import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical_example/support/device_tilt.dart';
import 'package:kiss_physical_example/support/kit_palette.dart';
import 'package:kiss_physical_example/support/pointer_light.dart';
import 'package:widgetbook/widgetbook.dart';

/// What the kit addon lets the viewer change for every use case.
@immutable
class KitSetting {
  const KitSetting({
    required this.accent,
    required this.hour,
    required this.light,
    required this.followsDevice,
    required this.onPegboard,
  });

  final Color accent;

  /// Hour of the day lighting the components, from 0 to 24.
  final double hour;

  /// Where the light hangs over the screen before the time of day leans it.
  final Offset light;

  /// Whether the light hangs still in the world as a handheld device tilts
  /// beneath it, in place of sitting where [light] puts it.
  final bool followsDevice;

  /// Whether use cases sit on a pegboard panel or on a plain background.
  final bool onPegboard;
}

/// Wraps every use case in what the kit needs: semantic colours with the
/// chosen accent, a theme and a light for the physical components.
class KitAddon extends WidgetbookAddon<KitSetting> {
  KitAddon() : super(name: 'Light and colour');

  static const _accent = 'accent';
  static const _hour = 'hour of day';
  static const _lightAcross = 'light across';
  static const _lightDown = 'light down';
  static const _followDevice = 'light follows device tilt or pointer';
  static const _pegboard = 'pegboard';

  static const _hoursPerDay = 24.0;
  static const _midday = 12.0;
  static const _lightReach = 1.0;

  @override
  List<Field> get fields => [
        ObjectDropdownField<String>(
          name: _accent,
          values: KitPalette.accents.keys.toList(),
          initialValue: KitPalette.accents.keys.first,
        ),
        DoubleSliderField(
          name: _hour,
          initialValue: _midday,
          min: 0,
          max: _hoursPerDay,
          precision: 2,
        ),
        DoubleSliderField(
          name: _lightAcross,
          initialValue: PhysicalLight.still.value.dx,
          min: -_lightReach,
          max: _lightReach,
          precision: 2,
        ),
        DoubleSliderField(
          name: _lightDown,
          initialValue: PhysicalLight.still.value.dy,
          min: -_lightReach,
          max: _lightReach,
          precision: 2,
        ),
        BooleanField(name: _followDevice),
        BooleanField(name: _pegboard),
      ];

  @override
  KitSetting valueFromQueryGroup(Map<String, String> group) {
    return KitSetting(
      accent: KitPalette.accents[valueOf<String>(_accent, group)] ??
          KitPalette.standardAccent,
      hour: valueOf<double>(_hour, group) ?? _midday,
      light: Offset(
        valueOf<double>(_lightAcross, group) ?? 0,
        valueOf<double>(_lightDown, group) ?? 0,
      ),
      followsDevice: valueOf<bool>(_followDevice, group) ?? true,
      onPegboard: valueOf<bool>(_pegboard, group) ?? true,
    );
  }

  @override
  Widget buildUseCase(
    BuildContext context,
    Widget child,
    KitSetting setting,
  ) {
    return KitScope(setting: setting, child: child);
  }
}

/// Provides colours, theme and light to [child] the way an app using the
/// kit does at its root.
class KitScope extends StatefulWidget {
  const KitScope({required this.setting, required this.child, super.key});

  final KitSetting setting;
  final Widget child;

  @override
  State<KitScope> createState() => _KitScopeState();
}

class _KitScopeState extends State<KitScope> {
  static const _referenceDay = (year: 2026, month: 6, day: 21);
  static const _latitude = 42.0;

  late final _direction = ValueNotifier<Offset>(Offset.zero);
  late final _tone = ValueNotifier<LightTone>(LightTone.neutral);
  late final _sky = ValueNotifier<SkyLight>(_skyAt(widget.setting.hour));

  @override
  void initState() {
    super.initState();
    PhysicalShader.precache();
    _showLight();
  }

  @override
  void didUpdateWidget(KitScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _showLight();
  }

  static SkyLight _skyAt(double hour) {
    final moment = DateTime(
      _referenceDay.year,
      _referenceDay.month,
      _referenceDay.day,
    ).add(Duration(seconds: (hour * Duration.secondsPerHour).round()));
    return SkyLight.at(moment, latitude: _latitude);
  }

  void _showLight() {
    final sky = _skyAt(widget.setting.hour);
    _sky.value = sky;
    _direction.value = widget.setting.light + sky.lean;
    _tone.value = sky.tone;
  }

  @override
  void dispose() {
    _direction.dispose();
    _tone.dispose();
    _sky.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = KitPalette.colorsWith(widget.setting.accent);
    return SemanticColors(
      data: colors,
      child: _Lighting(
        followsDevice: widget.setting.followsDevice,
        sky: _sky,
        direction: _direction,
        tone: _tone,
        child: Theme(
          data: colors.theme.copyWith(
            scaffoldBackgroundColor: colors.primary.background,
          ),
          child: DefaultTextStyle(
            style: TextStyle(color: colors.primary.foreground),
            child: _Backdrop(
              color: colors.primary.background,
              onPegboard: widget.setting.onPegboard,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lights [child] from a lamp that stays put in the world as the device
/// tilts, from the pointer where the device cannot feel tilt, or from a lamp
/// fixed over the screen at [direction].
class _Lighting extends StatelessWidget {
  const _Lighting({
    required this.followsDevice,
    required this.sky,
    required this.direction,
    required this.tone,
    required this.child,
  });

  final bool followsDevice;
  final ValueListenable<SkyLight> sky;
  final ValueListenable<Offset> direction;
  final ValueListenable<LightTone> tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!followsDevice) {
      return PhysicalLight(direction: direction, tone: tone, child: child);
    }
    if (DeviceTilt.isFelt) return WorldLight(sky: sky, child: child);
    return PointerLight(tone: tone, child: child);
  }
}

/// The panel behind a use case: a lit pegboard or a flat colour.
class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.color,
    required this.onPegboard,
    required this.child,
  });

  static const _depthBelowContent = 28.0;

  final Color color;
  final bool onPegboard;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!onPegboard) return ColoredBox(color: color, child: child);
    return PhysicalPegboard(
      color: color,
      scrollsWithContent: true,
      depth: _depthBelowContent,
      child: child,
    );
  }
}
