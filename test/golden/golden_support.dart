import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
/// separate one machine's software renderer from another's: a pixel counts
/// as changed only when a channel moves by more than a few levels, and a
/// sheet counts as changed only when more than a sliver of its pixels do.
class TolerantComparator extends LocalFileComparator {
  TolerantComparator(super.testFile);

  /// How far a channel may move, out of 255, before its pixel has changed.
  static const channelTolerance = 10;

  /// The share of pixels that may change before a sheet has changed.
  static const allowedShare = 0.002;

  static const _bytesPerPixel = 4;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final actual = await _pixelsOf(imageBytes);
    final expected = await _pixelsOf(
      Uint8List.fromList(await getGoldenBytes(golden)),
    );
    if (actual.length != expected.length) {
      throw FlutterError('$golden: the sheet has changed size.');
    }
    var changed = 0;
    for (var at = 0; at < actual.length; at += _bytesPerPixel) {
      if (_differs(actual, expected, at)) changed++;
    }
    final share = changed * _bytesPerPixel / actual.length;
    if (share <= allowedShare) return true;
    final percent = (share * 100).toStringAsFixed(2);
    throw FlutterError('$golden: $percent% of pixels have changed.');
  }

  static bool _differs(Uint8List a, Uint8List b, int at) {
    for (var channel = 0; channel < _bytesPerPixel; channel++) {
      if ((a[at + channel] - b[at + channel]).abs() > channelTolerance) {
        return true;
      }
    }
    return false;
  }

  static Future<Uint8List> _pixelsOf(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData();
    frame.image.dispose();
    codec.dispose();
    return data!.buffer.asUint8List();
  }
}

/// Whether the golden sheets can be trusted here. They are recorded on
/// macOS, and other platforms round their noise differently enough to
/// change the look of a texture.
bool get rendersLikeTheGoldens => Platform.isMacOS;

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
