import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/motion/physical_feel.dart';
import 'package:kiss_physical/src/motion/physical_haptics.dart';
import 'package:kiss_physical/src/motion/physical_motion.dart';
import 'package:kiss_physical/src/motion/spring_controller.dart';

class _Row {
  static const closed = 0.0;
}

/// A row that slides aside to show the actions lying behind it.
///
/// Dragged or thrown towards the end it uncovers its [startActions], and
/// towards the start its [endActions], settling open on whichever side the
/// throw would carry it to. Past the last action it gives a little and is
/// held. Tapping an open row closes it, and an action closes it with
/// [PhysicalSwipeRow.close]. The [child] should cover the whole row, as a
/// `PhysicalSurface` does, so the actions cannot be seen until it moves.
class PhysicalSwipeRow extends StatefulWidget {
  /// Creates a row of [child] with actions behind either end of it.
  const PhysicalSwipeRow({
    required this.child,
    this.startActions = const [],
    this.endActions = const [],
    this.actionExtent = defaultActionExtent,
    super.key,
  });

  /// The width each action is given unless another is set.
  static const defaultActionExtent = 64.0;

  /// What slides aside.
  final Widget child;

  /// The actions behind the start of the row, uncovered by sliding it
  /// towards the end.
  final List<Widget> startActions;

  /// The actions behind the end of the row, uncovered by sliding it
  /// towards the start.
  final List<Widget> endActions;

  /// The width each action is given, in logical pixels.
  final double actionExtent;

  /// Slides the row that holds [context] back over its actions. Call it
  /// from an action that leaves the row in place.
  static void close(BuildContext context) {
    context.getInheritedWidgetOfExactType<_SwipeRowScope>()?.close();
  }

  @override
  State<PhysicalSwipeRow> createState() => _PhysicalSwipeRowState();
}

class _PhysicalSwipeRowState extends State<PhysicalSwipeRow>
    with SingleTickerProviderStateMixin {
  late final _slide = SpringController(vsync: this);

  /// How far towards the end the finger has carried the row during the
  /// drag in progress.
  var _dragged = _Row.closed;

  /// Where the row is settling: closed, or open on one side.
  var _rest = _Row.closed;

  double get _startExtent => widget.startActions.length * widget.actionExtent;

  double get _endExtent => widget.endActions.length * widget.actionExtent;

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _settleAt(double rest, {double? velocity}) {
    if (rest != _rest) {
      if (rest != _Row.closed) {
        PhysicalHaptics.play(context, PhysicalHaptic.tick);
      }
      setState(() => _rest = rest);
    }
    _slide.springTo(
      rest,
      spring: PhysicalMotion.carry,
      velocity: velocity,
      tolerance: PhysicalMotion.settledInPixels,
    );
  }

  void _close() => _settleAt(_Row.closed);

  void _startDrag() => _dragged = _slide.value;

  void _drag(double towardsEnd) {
    _dragged += towardsEnd;
    _slide.value = _dragged;
  }

  void _endDrag(double velocityTowardsEnd) {
    final rests = [-_endExtent, _Row.closed, _startExtent];
    _settleAt(
      PhysicalMotion.stopFor(_slide.value, velocityTowardsEnd, rests),
      velocity: velocityTowardsEnd,
    );
  }

  /// How far towards the end the row shows for a [slide]: past its
  /// actions it gives a little and is held.
  double _shownAt(double slide) {
    return PhysicalMotion.heldWithin(
      slide,
      lowest: -_endExtent,
      highest: _startExtent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final towardsEnd =
        Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final isOpen = _rest != _Row.closed;
    return _SwipeRowScope(
      close: _close,
      child: GestureDetector(
        onHorizontalDragStart: (_) => _startDrag(),
        onHorizontalDragUpdate: (details) =>
            _drag(details.primaryDelta! * towardsEnd),
        onHorizontalDragEnd: (details) =>
            _endDrag(details.primaryVelocity! * towardsEnd),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  _Actions(
                    actions: widget.startActions,
                    extent: widget.actionExtent,
                    isUncovered: _rest > _Row.closed,
                  ),
                  const Spacer(),
                  _Actions(
                    actions: widget.endActions,
                    extent: widget.actionExtent,
                    isUncovered: _rest < _Row.closed,
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _slide,
              builder: (context, cover) => Transform.translate(
                offset: Offset(_shownAt(_slide.value) * towardsEnd, 0),
                child: cover,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isOpen ? _close : null,
                child: AbsorbPointer(absorbing: isOpen, child: widget.child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets what is inside a row close it.
class _SwipeRowScope extends InheritedWidget {
  const _SwipeRowScope({required this.close, required super.child});

  final VoidCallback close;

  @override
  bool updateShouldNotify(_SwipeRowScope oldWidget) => false;
}

/// The actions behind one end of a row, which answer the pointer only
/// while the row has moved off them.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.actions,
    required this.extent,
    required this.isUncovered,
  });

  final List<Widget> actions;
  final double extent;
  final bool isUncovered;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isUncovered,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            SizedBox(width: extent, child: Center(child: action)),
        ],
      ),
    );
  }
}
