import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/motion/physical_feel.dart';
import 'package:kiss_physical/src/motion/physical_haptics.dart';
import 'package:kiss_physical/src/motion/physical_motion.dart';
import 'package:kiss_physical/src/motion/spring_controller.dart';

class _Pages {
  static const first = 0;
  static const one = 1;
}

/// Pages side by side, one in view, that are dragged or thrown from one to
/// the next and settle on a spring.
///
/// A throw carries the pager one page at most. Past the first or last
/// page it gives a little and is held. The pager fills the space it is
/// given, and builds only the pages in view.
class PhysicalPager extends StatefulWidget {
  /// Creates a pager of [itemCount] pages showing [page].
  const PhysicalPager({
    required this.itemCount,
    required this.itemBuilder,
    required this.page,
    required this.onPageChanged,
    this.semanticLabel,
    super.key,
  }) : assert(itemCount > 0, 'there must be a page to show');

  /// How many pages there are.
  final int itemCount;

  /// Builds the page at an index from 0 to one less than [itemCount].
  final IndexedWidgetBuilder itemBuilder;

  /// The index of the page in view.
  final int page;

  /// Called with the index of the page the pager is thrown to.
  final ValueChanged<int> onPageChanged;

  /// What the pager is called by screen readers.
  final String? semanticLabel;

  @override
  State<PhysicalPager> createState() => _PhysicalPagerState();
}

class _PhysicalPagerState extends State<PhysicalPager>
    with SingleTickerProviderStateMixin {
  late final _position = SpringController(
    vsync: this,
    value: _page.toDouble(),
  );
  final _built = <int, Widget>{};

  /// Where the finger has carried the pager during the drag in progress,
  /// counted in pages.
  var _dragged = 0.0;

  int get _last => widget.itemCount - _Pages.one;

  int get _page => widget.page.clamp(_Pages.first, _last);

  @override
  void didUpdateWidget(PhysicalPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    _built.clear();
    if (oldWidget.page != widget.page) _settle();
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _settle({double? velocity}) {
    _position.springTo(
      _page.toDouble(),
      spring: PhysicalMotion.carry,
      velocity: velocity,
    );
  }

  void _turnTo(int page) {
    final held = page.clamp(_Pages.first, _last);
    if (held == _page) return;
    PhysicalHaptics.play(context, PhysicalHaptic.tick);
    widget.onPageChanged(held);
  }

  void _startDrag() => _dragged = _position.value;

  void _drag(double pagesOn) {
    _dragged += pagesOn;
    _position.value = _dragged;
  }

  void _endDrag(double pagesASecond) {
    final neighbours = [
      for (var page = _page - _Pages.one; page <= _page + _Pages.one; page++)
        if (page >= _Pages.first && page <= _last) page.toDouble(),
    ];
    final rest = PhysicalMotion.stopFor(
      _position.value,
      pagesASecond,
      neighbours,
    );
    _settle(velocity: pagesASecond);
    _turnTo(rest.round());
  }

  /// Where the pager shows for a [position] counted in pages: past either
  /// end it gives a little and is held.
  double _shownAt(double position) {
    return PhysicalMotion.heldWithin(
      position,
      lowest: _Pages.first.toDouble(),
      highest: _last.toDouble(),
    );
  }

  /// What a screen reader calls the page at [index], or nothing for one
  /// past either end.
  String _named(int index) {
    final isAPage = index >= _Pages.first && index <= _last;
    return isAPage ? '${index + _Pages.one} / ${widget.itemCount}' : '';
  }

  Widget _pageAt(BuildContext context, int index) {
    return _built[index] ??= widget.itemBuilder(context, index);
  }

  @override
  Widget build(BuildContext context) {
    final towardsEnd = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: _named(_page),
      increasedValue: _named(_page + _Pages.one),
      decreasedValue: _named(_page - _Pages.one),
      onIncrease: _page < _last ? () => _turnTo(_page + _Pages.one) : null,
      onDecrease:
          _page > _Pages.first ? () => _turnTo(_page - _Pages.one) : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pagesAPixel = -towardsEnd / constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _startDrag(),
            onHorizontalDragUpdate: (details) =>
                _drag(details.primaryDelta! * pagesAPixel),
            onHorizontalDragEnd: (details) =>
                _endDrag(details.primaryVelocity! * pagesAPixel),
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _position,
                builder: (context, _) {
                  final shown = _shownAt(_position.value);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      for (var index = shown.floor();
                          index <= shown.ceil();
                          index++)
                        if (index >= _Pages.first && index <= _last)
                          FractionalTranslation(
                            key: ValueKey(index),
                            translation: Offset(
                              (index - shown) * towardsEnd,
                              0,
                            ),
                            child: _pageAt(context, index),
                          ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
