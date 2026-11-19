import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';

/// The values components fall back to when none are given.
///
/// They come from the nearest `Layout` and [SemanticColors] where an app
/// provides them, and from the standard layout and the theme otherwise, so
/// components work with no set-up.
abstract final class PhysicalDefaults {
  /// The large corner radius of the nearest `Layout`, or of the standard
  /// layout without one.
  static double cornerRadius(BuildContext context) {
    final radii =
        Layout.maybeOf(context)?.cornerRadii ?? LayoutData.standard.cornerRadii;
    return radii.large;
  }

  /// The secondary background of the nearest [SemanticColors], or the
  /// surface colour of the theme without one.
  static Color surfaceColor(BuildContext context) {
    final colors = context.dependOnInheritedWidgetOfExactType<SemanticColors>();
    return colors?.data.secondary.background ??
        Theme.of(context).colorScheme.surface;
  }
}
