import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Sample {
  static const color = Color(0xFF3366CC);
  static const width = 300.0;
  static const sheetHeight = 200.0;
  static const rowHeight = 60.0;
  static const pageCount = 3;
  static const flick = 1500.0;
  static const sheet = Key('sheet');
  static const row = Key('row');
  static const pager = Key('pager');
  static const archive = 'Archive';
  static const delete = 'Delete';
}

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: PhysicalHaptics(
        isEnabled: false,
        child: Scaffold(
          body: Center(child: SizedBox(width: _Sample.width, child: child)),
        ),
      ),
    ),
  );
}

Widget _sheet({required VoidCallback onDismissed, bool isDismissible = true}) {
  return PhysicalSheet(
    onDismissed: onDismissed,
    isDismissible: isDismissible,
    child: const ColoredBox(
      key: _Sample.sheet,
      color: _Sample.color,
      child: SizedBox(height: _Sample.sheetHeight, width: _Sample.width),
    ),
  );
}

Widget _row({required List<String> taps}) {
  return PhysicalSwipeRow(
    startActions: [
      TextButton(
        onPressed: () => taps.add(_Sample.archive),
        child: const Text(_Sample.archive),
      ),
    ],
    endActions: [
      Builder(
        builder: (context) => TextButton(
          onPressed: () {
            taps.add(_Sample.delete);
            PhysicalSwipeRow.close(context);
          },
          child: const Text(_Sample.delete),
        ),
      ),
    ],
    child: const ColoredBox(
      key: _Sample.row,
      color: _Sample.color,
      child: SizedBox(height: _Sample.rowHeight, width: _Sample.width),
    ),
  );
}

/// A pager that keeps its own page, as an app would.
class _Pager extends StatefulWidget {
  const _Pager({required this.turns, this.initialPage = 0});

  final List<int> turns;
  final int initialPage;

  @override
  State<_Pager> createState() => _PagerState();
}

class _PagerState extends State<_Pager> {
  late int _page = widget.initialPage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _Sample.sheetHeight,
      child: PhysicalPager(
        key: _Sample.pager,
        itemCount: _Sample.pageCount,
        page: _page,
        onPageChanged: (page) {
          widget.turns.add(page);
          setState(() => _page = page);
        },
        itemBuilder: (context, index) => Center(child: Text('Page $index')),
      ),
    );
  }
}

double _left(WidgetTester tester, Finder finder) {
  return tester.getTopLeft(finder).dx;
}

void main() {
  group('PhysicalSheet', () {
    testWidgets('dragged a little, it settles back', (tester) async {
      var dismissals = 0;
      await tester.pumpWidget(_app(_sheet(onDismissed: () => dismissals++)));
      final rest = tester.getTopLeft(find.byKey(_Sample.sheet));

      await tester.drag(find.byKey(_Sample.sheet), const Offset(0, 40));
      await tester.pumpAndSettle();

      expect(dismissals, 0);
      expect(tester.getTopLeft(find.byKey(_Sample.sheet)), rest);
    });

    testWidgets('follows the finger down', (tester) async {
      await tester.pumpWidget(_app(_sheet(onDismissed: () {})));
      final rest = tester.getTopLeft(find.byKey(_Sample.sheet)).dy;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_Sample.sheet)),
      );
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();

      final moved = tester.getTopLeft(find.byKey(_Sample.sheet)).dy - rest;
      expect(moved, greaterThan(30));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('dragged most of the way out, it leaves', (tester) async {
      var dismissals = 0;
      await tester.pumpWidget(_app(_sheet(onDismissed: () => dismissals++)));

      await tester.drag(find.byKey(_Sample.sheet), const Offset(0, 150));
      await tester.pumpAndSettle();

      expect(dismissals, 1);
    });

    testWidgets('thrown down, it leaves', (tester) async {
      var dismissals = 0;
      await tester.pumpWidget(_app(_sheet(onDismissed: () => dismissals++)));

      await tester.fling(
        find.byKey(_Sample.sheet),
        const Offset(0, 80),
        _Sample.flick,
      );
      await tester.pumpAndSettle();

      expect(dismissals, 1);
    });

    testWidgets('lifted, it gives only a little', (tester) async {
      await tester.pumpWidget(_app(_sheet(onDismissed: () {})));
      final rest = tester.getTopLeft(find.byKey(_Sample.sheet)).dy;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_Sample.sheet)),
      );
      await gesture.moveBy(const Offset(0, -50));
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();

      final lifted = rest - tester.getTopLeft(find.byKey(_Sample.sheet)).dy;
      expect(lifted, greaterThan(0));
      expect(lifted, lessThan(24));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(_Sample.sheet)).dy, rest);
    });

    testWidgets('one that cannot be dismissed always settles back',
        (tester) async {
      var dismissals = 0;
      await tester.pumpWidget(
        _app(_sheet(onDismissed: () => dismissals++, isDismissible: false)),
      );

      await tester.fling(
        find.byKey(_Sample.sheet),
        const Offset(0, 150),
        _Sample.flick,
      );
      await tester.pumpAndSettle();

      expect(dismissals, 0);
    });
  });

  group('PhysicalSwipeRow', () {
    testWidgets('slid towards the start, it uncovers its end action',
        (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(_app(_row(taps: taps)));
      final rest = _left(tester, find.byKey(_Sample.row));

      await tester.drag(find.byKey(_Sample.row), const Offset(-60, 0));
      await tester.pumpAndSettle();

      expect(
        _left(tester, find.byKey(_Sample.row)),
        rest - PhysicalSwipeRow.defaultActionExtent,
      );
      await tester.tap(find.text(_Sample.delete));
      await tester.pumpAndSettle();
      expect(taps, [_Sample.delete]);
      expect(_left(tester, find.byKey(_Sample.row)), rest);
    });

    testWidgets('slid towards the end, it uncovers its start action',
        (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(_app(_row(taps: taps)));
      final rest = _left(tester, find.byKey(_Sample.row));

      await tester.drag(find.byKey(_Sample.row), const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(
        _left(tester, find.byKey(_Sample.row)),
        rest + PhysicalSwipeRow.defaultActionExtent,
      );
      await tester.tap(find.text(_Sample.archive));
      expect(taps, [_Sample.archive]);
    });

    testWidgets('nudged, it closes again and its actions stay covered',
        (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(_app(_row(taps: taps)));
      final rest = _left(tester, find.byKey(_Sample.row));

      await tester.drag(find.byKey(_Sample.row), const Offset(-24, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_Sample.delete), warnIfMissed: false);

      expect(_left(tester, find.byKey(_Sample.row)), rest);
      expect(taps, isEmpty);
    });

    testWidgets('an open row closes when tapped', (tester) async {
      await tester.pumpWidget(_app(_row(taps: [])));
      final rest = _left(tester, find.byKey(_Sample.row));
      await tester.drag(find.byKey(_Sample.row), const Offset(-60, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_Sample.row));
      await tester.pumpAndSettle();

      expect(_left(tester, find.byKey(_Sample.row)), rest);
    });

    testWidgets('never shows as slid far past its actions', (tester) async {
      await tester.pumpWidget(_app(_row(taps: [])));
      final rest = _left(tester, find.byKey(_Sample.row));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_Sample.row)),
      );
      await gesture.moveBy(const Offset(-50, 0));
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();

      final slid = rest - _left(tester, find.byKey(_Sample.row));
      expect(slid, greaterThan(PhysicalSwipeRow.defaultActionExtent));
      expect(slid, lessThan(PhysicalSwipeRow.defaultActionExtent * 2.5));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('is mirrored when text runs right to left', (tester) async {
      await tester.pumpWidget(
        _app(_row(taps: []), direction: TextDirection.rtl),
      );
      final rest = _left(tester, find.byKey(_Sample.row));

      await tester.drag(find.byKey(_Sample.row), const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(
        _left(tester, find.byKey(_Sample.row)),
        rest + PhysicalSwipeRow.defaultActionExtent,
      );
      await tester.tap(find.text(_Sample.delete));
      await tester.pumpAndSettle();
      expect(_left(tester, find.byKey(_Sample.row)), rest);
    });
  });

  group('PhysicalPager', () {
    testWidgets('builds only the page in view', (tester) async {
      await tester.pumpWidget(_app(const _Pager(turns: [])));

      expect(find.text('Page 0'), findsOneWidget);
      expect(find.text('Page 1'), findsNothing);
    });

    testWidgets('dragged most of the way, it turns to the next page',
        (tester) async {
      final turns = <int>[];
      await tester.pumpWidget(_app(_Pager(turns: turns)));

      await tester.drag(find.byKey(_Sample.pager), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(turns, [1]);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 0'), findsNothing);
    });

    testWidgets('nudged, it settles back on its page', (tester) async {
      final turns = <int>[];
      await tester.pumpWidget(_app(_Pager(turns: turns)));

      await tester.drag(find.byKey(_Sample.pager), const Offset(-40, 0));
      await tester.pumpAndSettle();

      expect(turns, isEmpty);
      expect(find.text('Page 0'), findsOneWidget);
    });

    testWidgets('a throw carries it one page and no further', (tester) async {
      final turns = <int>[];
      await tester.pumpWidget(_app(_Pager(turns: turns)));

      await tester.fling(
        find.byKey(_Sample.pager),
        const Offset(-60, 0),
        _Sample.flick * 4,
      );
      await tester.pumpAndSettle();

      expect(turns, [1]);
    });

    testWidgets('is held at its first and last pages', (tester) async {
      final turns = <int>[];
      await tester.pumpWidget(
        _app(_Pager(turns: turns, initialPage: _Sample.pageCount - 1)),
      );

      await tester.fling(
        find.byKey(_Sample.pager),
        const Offset(-200, 0),
        _Sample.flick,
      );
      await tester.pumpAndSettle();

      expect(turns, isEmpty);
      expect(find.text('Page 2'), findsOneWidget);
    });

    testWidgets('turns the other way when text runs right to left',
        (tester) async {
      final turns = <int>[];
      await tester.pumpWidget(
        _app(_Pager(turns: turns), direction: TextDirection.rtl),
      );

      await tester.drag(find.byKey(_Sample.pager), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(turns, [1]);
    });

    testWidgets('can be turned by a screen reader', (tester) async {
      final turns = <int>[];
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_Pager(turns: turns)));

      tester.semantics.increase(find.semantics.byValue('1 / 3'));
      await tester.pumpAndSettle();

      expect(turns, [1]);
      handle.dispose();
    });
  });

  test('a carried body settles within its tolerance in pixels', () {
    expect(PhysicalMotion.settledInPixels.distance, lessThan(1));
    expect(PhysicalMotion.carry.mass, greaterThan(0));
  });
}
