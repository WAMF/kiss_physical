import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Draws a ring around [child] while [isShown], to mark keyboard focus.
///
/// Only the ring repaints as focus comes and goes; [child] is left alone.
class PhysicalFocusRing extends StatelessWidget {
  /// Creates a focus ring around [child].
  const PhysicalFocusRing({
    required this.isShown,
    required this.borderRadius,
    required this.child,
    super.key,
  });

  /// The thickness of the ring in logical pixels.
  static const width = 2.0;

  /// Whether the ring is drawn.
  final ValueListenable<bool> isShown;

  /// The corner radii of the body the ring goes round.
  final BorderRadius borderRadius;

  /// The body the ring goes round.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return ValueListenableBuilder<bool>(
      valueListenable: isShown,
      child: child,
      builder: (context, isShown, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: isShown ? Border.all(color: color, width: width) : null,
        ),
        child: child,
      ),
    );
  }
}
