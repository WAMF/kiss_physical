import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical/src/surface/surface_bake.dart';

class _Fixture {
  static const size = Size(40, 20);
  static const pixelRatio = 2.0;
  static const oak = 'oak';
  static const granite = 'granite';
  static const tooLarge = Size(4000, 20);
}

void main() {
  late SurfaceBake bake;
  late int bakes;

  Image? mapsFor(Object key, {Size size = _Fixture.size}) {
    return bake.mapsFor(
      key,
      size: size,
      pixelRatio: _Fixture.pixelRatio,
      bake: (canvas, area) {
        bakes++;
        canvas.drawRect(area, Paint());
      },
    );
  }

  setUp(() {
    bake = SurfaceBake();
    bakes = 0;
  });

  tearDown(() => bake.dispose());

  test('a body is not baked the first time it is seen', () {
    expect(mapsFor(_Fixture.oak), isNull);
    expect(bakes, 0);
  });

  test('a body that has settled is baked once and then kept', () {
    mapsFor(_Fixture.oak);
    final maps = mapsFor(_Fixture.oak);

    expect(maps, isNotNull);
    expect(mapsFor(_Fixture.oak), same(maps));
    expect(bakes, 1);
  });

  test('the maps hold four tiles at the device resolution', () {
    mapsFor(_Fixture.oak);
    final maps = mapsFor(_Fixture.oak)!;

    expect(
      SurfaceBake.sizeOf(maps, _Fixture.pixelRatio),
      _Fixture.size * 2,
    );
  });

  test('a body that keeps changing is never baked', () {
    mapsFor(_Fixture.oak);
    expect(mapsFor(_Fixture.granite), isNull);
    expect(mapsFor(_Fixture.oak), isNull);
    expect(bakes, 0);
  });

  test('a body too large to keep is drawn directly', () {
    mapsFor(_Fixture.oak, size: _Fixture.tooLarge);

    expect(mapsFor(_Fixture.oak, size: _Fixture.tooLarge), isNull);
    expect(bakes, 0);
  });

  test('wood burns most readily and metal least', () {
    double flammabilityOf(PhysicalTexture texture) =>
        PhysicalMaterial.satin.withTexture(texture).flammability;

    final oak = flammabilityOf(PhysicalTexture.oak);
    final plastic = flammabilityOf(PhysicalTexture.plastic);
    final granite = flammabilityOf(PhysicalTexture.granite);
    final brass = flammabilityOf(PhysicalTexture.brass);

    expect(oak, greaterThan(plastic));
    expect(plastic, greaterThan(granite));
    expect(granite, greaterThan(brass));
    expect(brass, greaterThan(0));
  });
}
