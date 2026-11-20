import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Fixture {
  static const height = 40.0;
  static const short = 120.0;
  static const long = 200.0;
  static const color = Color(0xFF8A6A4A);
  static final material = PhysicalMaterial.satin
      .copyWith(crown: 0)
      .withTexture(PhysicalTexture.oak);

  /// A strip of the face well inside both lengths and clear of the bevel.
  static const strip = Rect.fromLTRB(20, 12, 90, 28);
  static const bytesPerPixel = 4;

  /// The mean difference per channel, out of 255, below which two strips
  /// show the same grain and above which they do not.
  static const sameGrain = 2.0;
}

Future<Uint8List> _stripOf(
  WidgetTester tester, {
  required double width,
  required AlignmentGeometry pinnedTo,
}) async {
  final boundary = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: boundary,
          child: SizedBox(
            width: width,
            height: _Fixture.height,
            child: PhysicalSurface(
              color: _Fixture.color,
              material: _Fixture.material,
              textureAlignment: pinnedTo,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final pixels = await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final data = await image.toByteData();
    final rowBytes = image.width * _Fixture.bytesPerPixel;
    image.dispose();
    return _cut(data!.buffer.asUint8List(), rowBytes);
  });
  return pixels!;
}

Uint8List _cut(Uint8List pixels, int rowBytes) {
  const strip = _Fixture.strip;
  final cut = BytesBuilder();
  for (var y = strip.top.toInt(); y < strip.bottom.toInt(); y++) {
    final row = y * rowBytes;
    cut.add(
      pixels.sublist(
        row + strip.left.toInt() * _Fixture.bytesPerPixel,
        row + strip.right.toInt() * _Fixture.bytesPerPixel,
      ),
    );
  }
  return cut.toBytes();
}

double _meanDifference(Uint8List a, Uint8List b) {
  var total = 0;
  for (var at = 0; at < a.length; at++) {
    total += (a[at] - b[at]).abs();
  }
  return total / a.length;
}

void main() {
  testWidgets('a texture pinned to the start stays put as the body grows', (
    tester,
  ) async {
    await tester.runAsync(PhysicalShader.precacheAll);

    final short = await _stripOf(
      tester,
      width: _Fixture.short,
      pinnedTo: AlignmentDirectional.centerStart,
    );
    final long = await _stripOf(
      tester,
      width: _Fixture.long,
      pinnedTo: AlignmentDirectional.centerStart,
    );

    expect(_meanDifference(short, long), lessThan(_Fixture.sameGrain));
  });

  testWidgets('a texture pinned to the centre moves as the body grows', (
    tester,
  ) async {
    await tester.runAsync(PhysicalShader.precacheAll);

    final short = await _stripOf(
      tester,
      width: _Fixture.short,
      pinnedTo: Alignment.center,
    );
    final long = await _stripOf(
      tester,
      width: _Fixture.long,
      pinnedTo: Alignment.center,
    );

    expect(_meanDifference(short, long), greaterThan(_Fixture.sameGrain));
  });

  testWidgets('the bar of a progress bar is pinned to its start', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PhysicalProgressBar(
          fraction: 0.5,
          barColor: _Fixture.color,
          trackColor: _Fixture.color,
        ),
      ),
    );

    final bar =
        tester.widgetList<PhysicalSurface>(find.byType(PhysicalSurface)).last;

    expect(bar.textureAlignment, AlignmentDirectional.centerStart);
  });
}
