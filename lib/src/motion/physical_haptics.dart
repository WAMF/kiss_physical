import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/motion/physical_feel.dart';

/// Says whether the physical bodies below it tap the hand when touched.
///
/// Bodies tap by default. Wrap an app, or part of one, in this with
/// [isEnabled] false to keep them quiet.
class PhysicalHaptics extends InheritedWidget {
  /// Creates a scope that turns the taps of the bodies in [child] on or
  /// off.
  const PhysicalHaptics({
    required this.isEnabled,
    required super.child,
    super.key,
  });

  /// Whether bodies below this tap the hand.
  final bool isEnabled;

  /// Gives [haptic] to the hand, unless the bodies around [context] are
  /// kept quiet.
  static void play(BuildContext context, PhysicalHaptic haptic) {
    final scope = context.getInheritedWidgetOfExactType<PhysicalHaptics>();
    if (scope != null && !scope.isEnabled) return;
    final tap = switch (haptic) {
      PhysicalHaptic.none => null,
      PhysicalHaptic.tick => HapticFeedback.selectionClick,
      PhysicalHaptic.light => HapticFeedback.lightImpact,
      PhysicalHaptic.medium => HapticFeedback.mediumImpact,
      PhysicalHaptic.heavy => HapticFeedback.heavyImpact,
    };
    if (tap != null) unawaited(tap());
  }

  @override
  bool updateShouldNotify(PhysicalHaptics oldWidget) {
    return oldWidget.isEnabled != isEnabled;
  }
}
