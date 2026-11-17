import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';

/// The neutral dark colours the storybook shows the kit in.
abstract final class KitPalette {
  /// The accent the storybook opens with.
  static const standardAccent = Color(0xFFD71921);

  /// Accents the viewer can pick between, by name.
  static const accents = {
    'Red': standardAccent,
    'Orange': Color(0xFFF26B1D),
    'Amber': Color(0xFFF2A900),
    'Green': Color(0xFF2EAD5B),
    'Teal': Color(0xFF12A5A0),
    'Blue': Color(0xFF2F7BF6),
    'Violet': Color(0xFF8E4EC6),
  };

  static const _clear = Color(0x00000000);
  static const _ink = Color(0xFF1A1D1C);
  static const _paper = Color(0xFFFFFFFF);
  static const _panel = Color(0xFF3B393E);
  static const _softShadow = Color(0x80000000);
  static const _muted = Color(0xFFCED4DA);
  static const _warning = Color(0xFFF1C40F);
  static const _error = Color(0xFFE74C3C);

  /// The storybook's colours with [accent] as the brand colour.
  static SemanticColorsData colorsWith(Color accent) {
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.light
            ? _ink
            : _paper;
    final brand = BaseColors(
      background: accent,
      foreground: onAccent,
      outline: accent,
      shadow: _softShadow,
    );
    return SemanticColorsData(
      primary: const BaseColors(
        background: _ink,
        foreground: _paper,
        outline: _clear,
        shadow: _clear,
      ),
      secondary: const BaseColors(
        background: _panel,
        foreground: _paper,
        outline: _paper,
        shadow: _softShadow,
      ),
      brand: BrandColors(
        primary: brand,
        secondary: const BaseColors(
          background: _paper,
          foreground: _ink,
          outline: _muted,
          shadow: _softShadow,
        ),
      ),
      state: StateColors(
        success: brand,
        error: _state(_error, _paper),
        warning: _state(_warning, _ink),
        disabled: _state(_muted, _paper),
      ),
    );
  }

  static BaseColors _state(Color background, Color foreground) {
    return BaseColors(
      background: background,
      foreground: foreground,
      outline: background,
      shadow: _softShadow,
    );
  }
}
