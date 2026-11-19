import 'dart:ui';

import 'package:kiss_physical/src/material/physical_material.dart';

/// How a control looks when it cannot be used: frosted over, so its colour
/// is greyed and its shine, dome and shadow are gone.
abstract final class DisabledLook {
  /// How strongly text and icons on a disabled control still show.
  static const foregroundAlpha = 0.45;

  /// The grey a disabled control's colour is drawn towards.
  static const _frost = Color(0xFF5E5D63);

  /// Share of the way the colour moves to [_frost].
  static const _frostAmount = 0.72;
  static const _roughness = 0.95;
  static const _reliefScale = 0.35;

  /// [color] greyed, keeping its opacity.
  static Color frosted(Color color) {
    return Color.lerp(color, _frost, _frostAmount)!.withValues(alpha: color.a);
  }

  /// [material] with its shine, dome and shadow removed.
  static PhysicalMaterial flattened(PhysicalMaterial material) {
    return material.copyWith(
      roughness: _roughness,
      specularTint: 0,
      crown: 0,
      relief: material.relief * _reliefScale,
      elevation: 0,
    );
  }
}
