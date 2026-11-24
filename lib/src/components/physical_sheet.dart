import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/motion/physical_feel.dart';
import 'package:kiss_physical/src/motion/physical_haptics.dart';
import 'package:kiss_physical/src/motion/physical_motion.dart';
import 'package:kiss_physical/src/motion/spring_controller.dart';

class _Sheet {
  static const rest = 0.0;
  static const smallestHeight = 1.0;

  /// The furthest a sheet shows as moved in a direction it cannot go.
  static const slack = 24.0;
}

/// Something docked to the bottom edge, such as a `PhysicalPanel.bottom`,
/// that can be dragged or thrown down out of the way.
///
/// Let go, the sheet settles back unless the throw would carry it more
/// than half way out, when it leaves and [onDismissed] is called; whoever
/// showed the sheet then takes it away. Lifted, it gives a little and is
/// held. Something inside that scrolls up and down takes the drag itself.
class PhysicalSheet extends StatefulWidget {
  /// Creates a sheet holding [child] that can be thrown away.
  const PhysicalSheet({
    required this.child,
    required this.onDismissed,
    this.isDismissible = true,
    super.key,
  });

  /// What the sheet holds.
  final Widget child;

  /// Called once the sheet has been thrown out of sight.
  final VoidCallback onDismissed;

  /// Whether the sheet can be thrown away. When not, it gives a little
  /// under a drag and settles back.
  final bool isDismissible;

  @override
  State<PhysicalSheet> createState() => _PhysicalSheetState();
}

class _PhysicalSheetState extends State<PhysicalSheet>
    with SingleTickerProviderStateMixin {
  late final _offset = SpringController(vsync: this);

  /// How far down the finger has carried the sheet during the drag in
  /// progress.
  var _dragged = _Sheet.rest;
  var _height = _Sheet.smallestHeight;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _startDrag() {
    _height = math.max(context.size?.height ?? 0, _Sheet.smallestHeight);
    _dragged = _offset.value;
  }

  void _drag(double down) {
    _dragged += down;
    _offset.value = _dragged;
  }

  TickerFuture _settleAt(double offset, double velocity) {
    return _offset.springTo(
      offset,
      spring: PhysicalMotion.carry,
      velocity: velocity,
      tolerance: PhysicalMotion.settledInPixels,
    );
  }

  bool _leavesWhenLetGoAt(double velocity) {
    if (!widget.isDismissible) return false;
    final rests = [_Sheet.rest, _height];
    return PhysicalMotion.stopFor(_offset.value, velocity, rests) == _height;
  }

  void _endDrag(double velocity) {
    if (!_leavesWhenLetGoAt(velocity)) {
      _settleAt(_Sheet.rest, velocity);
      return;
    }
    PhysicalHaptics.play(context, PhysicalHaptic.light);
    _settleAt(_height, velocity).then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  /// How far down the sheet shows for an [offset]: where it cannot go it
  /// gives a little and is held.
  double _shownAt(double offset) {
    final isHeld = offset < _Sheet.rest || !widget.isDismissible;
    if (!isHeld) return offset;
    return PhysicalMotion.resisted(offset, extent: _Sheet.slack);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      onDismiss: widget.isDismissible ? widget.onDismissed : null,
      child: GestureDetector(
        onVerticalDragStart: (_) => _startDrag(),
        onVerticalDragUpdate: (details) => _drag(details.primaryDelta!),
        onVerticalDragEnd: (details) => _endDrag(details.primaryVelocity!),
        child: AnimatedBuilder(
          animation: _offset,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _shownAt(_offset.value)),
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
