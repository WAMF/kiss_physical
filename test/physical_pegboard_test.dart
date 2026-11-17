import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical/src/surface/physical_pegboard.dart';

void main() {
  group('PegboardGrid', () {
    test('puts about 27 sockets across a handset', () {
      const grid = PegboardGrid();

      expect(grid.columnsIn(390), 26);
      expect(grid.columnsIn(412), 27);
      expect(grid.columnsIn(430), 28);
    });

    test('centres the columns across the width', () {
      const grid = PegboardGrid(pitch: 20, socketRadius: 3);
      const width = 390.0;

      final origin = grid.originFor(width);
      final used = grid.columnsIn(width) * grid.pitch;

      expect(origin, 5);
      expect(width - origin - used, origin);
    });

    test('starts at the edge when the columns fit exactly', () {
      const grid = PegboardGrid(pitch: 20, socketRadius: 3);

      expect(grid.originFor(400), 0);
      expect(grid.columnsIn(400), 20);
    });

    test('an empty width holds no sockets', () {
      const grid = PegboardGrid();

      expect(grid.columnsIn(0), 0);
      expect(grid.originFor(0), 0);
    });

    test('grids with the same measurements are equal', () {
      expect(
        const PegboardGrid(pitch: 20, socketRadius: 3),
        const PegboardGrid(pitch: 20, socketRadius: 3),
      );
      expect(const PegboardGrid(pitch: 20), isNot(const PegboardGrid()));
    });

    test('keeps the proportions of the launch film panel', () {
      const filmSocketToPitch = 6.5 / 40;

      expect(
        PegboardGrid.defaultSocketRadius / PegboardGrid.defaultPitch,
        closeTo(filmSocketToPitch, 0.005),
      );
    });
  });

  group('PegboardGrid scrolling', () {
    const grid = PegboardGrid(pitch: 20, socketRadius: 3);
    const width = 390.0;

    test('resting rows start where the columns do', () {
      expect(grid.rowOriginFor(width, 0), grid.originFor(width));
    });

    test('rows move up by the distance the content scrolled down', () {
      expect(grid.rowOriginFor(width, 3), 2);
    });

    test('rows wrap within one cell however far the content travels', () {
      expect(grid.rowOriginFor(width, 8), 17);
      expect(grid.rowOriginFor(width, 4008), 17);
      expect(grid.rowOriginFor(width, 20), grid.originFor(width));
    });

    test('rows move down when the content bounces past its start', () {
      expect(grid.rowOriginFor(width, -6), 11);
      expect(grid.rowOriginFor(width, -16), 1);
    });
  });

  group('PegboardTravel', () {
    test('sums vertical scrolling and ignores horizontal scrolling', () {
      final travel = PegboardTravel();
      addTearDown(travel.dispose);

      travel
        ..move(30, AxisDirection.down)
        ..move(12, AxisDirection.down)
        ..move(100, AxisDirection.right)
        ..move(100, AxisDirection.left);

      expect(travel.value, 42);
    });

    test('a reversed scrollable moves the sockets the other way', () {
      final travel = PegboardTravel();
      addTearDown(travel.dispose);

      travel.move(30, AxisDirection.up);

      expect(travel.value, -30);
    });

    test('notifies only when the content moved', () {
      final travel = PegboardTravel();
      addTearDown(travel.dispose);
      var notified = 0;
      travel
        ..addListener(() => notified++)
        ..move(0, AxisDirection.down)
        ..move(100, AxisDirection.right)
        ..move(5, AxisDirection.down);

      expect(notified, 1);
    });
  });

  group('PhysicalPegboard', () {
    testWidgets('takes the size of its child', (tester) async {
      await tester.pumpWidget(
        const Center(
          child: PhysicalPegboard(
            color: Colors.black,
            child: SizedBox(width: 120, height: 40),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(PhysicalPegboard)),
        const Size(120, 40),
      );
    });

    testWidgets('fills the space it is given behind its child', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PhysicalPegboard(
            color: Colors.black,
            child: Center(child: Text('content')),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CustomPaint).first),
        tester.getSize(find.byType(PhysicalPegboard)),
      );
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('paints the flat panel colour until the shader is loaded', (
      tester,
    ) async {
      const panel = Color(0xFF1A1D1C);

      await tester.pumpWidget(
        const PhysicalPegboard(color: panel, child: SizedBox.expand()),
      );

      expect(
        find.descendant(
          of: find.byType(PhysicalPegboard),
          matching: find.byType(CustomPaint),
        ),
        paints
          ..rect(
            rect: Offset.zero & tester.getSize(find.byType(PhysicalPegboard)),
            color: panel,
          ),
      );
    });

    testWidgets('a change of light repaints only the board layer', (
      tester,
    ) async {
      final direction = ValueNotifier(Offset.zero);
      addTearDown(direction.dispose);
      var builds = 0;

      await tester.pumpWidget(
        PhysicalLight(
          direction: direction,
          child: PhysicalPegboard(
            color: Colors.black,
            child: RepaintBoundary(
              child: Builder(
                builder: (context) {
                  builds++;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      final board = tester.renderObject(
        find.descendant(
          of: find.byType(PhysicalPegboard),
          matching: find.byType(RepaintBoundary).first,
        ),
      );
      final content = tester.renderObject(
        find.descendant(
          of: find.byType(PhysicalPegboard),
          matching: find.byType(RepaintBoundary).last,
        ),
      );
      expect(board.debugNeedsPaint, isFalse);

      direction.value = const Offset(0.3, -0.2);

      expect(board.isRepaintBoundary, isTrue);
      expect(board.debugNeedsPaint, isTrue);
      expect(content.debugNeedsPaint, isFalse);
      await tester.pump();
      expect(builds, 1);
    });

    group('scrolling', () {
      Future<_Layers> pumpBoard(
        WidgetTester tester, {
        required bool scrollsWithContent,
        Axis axis = Axis.vertical,
        VoidCallback? onItemBuilt,
      }) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: PhysicalPegboard(
              color: Colors.black,
              scrollsWithContent: scrollsWithContent,
              child: ListView.builder(
                scrollDirection: axis,
                itemCount: 100,
                itemExtent: 100,
                itemBuilder: (context, index) {
                  onItemBuilt?.call();
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        );
        return _Layers.of(tester);
      }

      testWidgets('repaints the board when content scrolls vertically',
          (tester) async {
        final layers = await pumpBoard(tester, scrollsWithContent: true);

        await tester.drag(find.byType(ListView), const Offset(0, -40));

        expect(layers.board.debugNeedsPaint, isTrue);
      });

      testWidgets('scrolling the board does not rebuild the content',
          (tester) async {
        var builds = 0;
        await pumpBoard(
          tester,
          scrollsWithContent: true,
          onItemBuilt: () => builds++,
        );
        final built = builds;

        await tester.drag(find.byType(ListView), const Offset(0, -40));
        await tester.pump();

        expect(builds, built);
      });

      testWidgets('leaves the board alone when content scrolls sideways',
          (tester) async {
        final layers = await pumpBoard(
          tester,
          scrollsWithContent: true,
          axis: Axis.horizontal,
        );

        await tester.drag(find.byType(ListView), const Offset(-40, 0));

        expect(layers.board.debugNeedsPaint, isFalse);
      });

      testWidgets('stays fixed unless asked to scroll with content',
          (tester) async {
        final layers = await pumpBoard(tester, scrollsWithContent: false);

        await tester.drag(find.byType(ListView), const Offset(0, -40));

        expect(layers.board.debugNeedsPaint, isFalse);
      });
    });

    testWidgets('a still light schedules no frames', (tester) async {
      await tester.pumpWidget(
        const PhysicalPegboard(color: Colors.black, child: SizedBox.expand()),
      );

      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  test('a shifted origin wraps to stay within one cell', () {
    const grid = PegboardGrid();

    expect(grid.shifted(4, 3), 7);
    expect(grid.shifted(4, -6), PegboardGrid.defaultPitch - 2);
    expect(grid.shifted(PegboardGrid.defaultPitch - 1, 4), 3);
  });
}

class _Layers {
  const _Layers(this.board);

  factory _Layers.of(WidgetTester tester) {
    return _Layers(
      tester.renderObject(
        find
            .descendant(
              of: find.byType(PhysicalPegboard),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      ),
    );
  }

  final RenderObject board;
}
