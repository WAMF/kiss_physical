import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

/// Sizes and colours shared by the golden sheets.
abstract final class Sheet {
  static const swatch = 96.0;
  static const gap = 12.0;
  static const columns = 4;
  static const background = Color(0xFF1A1D1C);
  static const body = Color(0xFF3B393E);
  static const accent = Color(0xFFD71921);
  static const light = Offset(-0.25, -0.45);
  static const radius = BorderRadius.all(Radius.circular(18));
  static const width = columns * swatch + (columns + 1) * gap;
}

/// Compares golden images allowing the small differences in rounding that
/// separate one machine's software renderer from another's.
class TolerantComparator extends LocalFileComparator {
  TolerantComparator(super.testFile);

  /// The share of pixels that may differ before a sheet counts as changed.
  static const allowedDifference = 0.005;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= allowedDifference) return true;
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

/// Uses [TolerantComparator] for the golden files beside [testFile].
void useTolerantGoldens(String testFile) {
  final previous = goldenFileComparator;
  setUpAll(() {
    goldenFileComparator = TolerantComparator(Uri.parse(testFile));
  });
  tearDownAll(() => goldenFileComparator = previous);
}

/// Pumps [bodies] as a sheet of swatches under a fixed light and checks it
/// against the golden file called [name].
Future<void> expectSheet(
  WidgetTester tester,
  String name,
  List<Widget> bodies,
) async {
  await tester.runAsync(PhysicalShader.precacheAll);
  final rows = (bodies.length / Sheet.columns).ceil();
  final height = rows * Sheet.swatch + (rows + 1) * Sheet.gap;
  await tester.binding.setSurfaceSize(Size(Sheet.width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PhysicalLight(
        direction: const AlwaysStoppedAnimation(Sheet.light),
        child: ColoredBox(
          color: Sheet.background,
          child: Padding(
            padding: const EdgeInsets.all(Sheet.gap),
            child: Wrap(
              spacing: Sheet.gap,
              runSpacing: Sheet.gap,
              children: [
                for (final body in bodies)
                  SizedBox.square(dimension: Sheet.swatch, child: body),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('images/$name.png'),
  );
}

/// A slab of [material] in [color].
Widget slab(
  PhysicalMaterial material, {
  Color color = Sheet.body,
  BorderRadius borderRadius = Sheet.radius,
}) {
  return PhysicalSurface(
    color: color,
    material: material,
    borderRadius: borderRadius,
    child: const SizedBox.expand(),
  );
}
