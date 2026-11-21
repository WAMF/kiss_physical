import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Keeps the part of a physical body that is costly to draw and seldom
/// changes: its texture and its wear.
///
/// The surface shader works in layers. Those three do not move and do not
/// depend on the light, so they are baked once into a sheet of maps and
/// read back every frame, leaving only the light, water and effects to be
/// worked out as they change.
///
/// A body is described by a key holding everything the baked layers
/// depend on. It is baked once the same key has been asked for twice
/// running, so a body that is changing every frame, as when a slider is
/// being dragged, is drawn directly until it settles.
class SurfaceBake {
  ui.Image? _maps;
  Object? _baked;
  Object? _wanted;

  /// The baked maps for the body [key] describes, or null while it has not
  /// settled or is too large to keep.
  ///
  /// [bake] must fill the area it is given, which is two surfaces wide and
  /// two high, with the maps.
  ui.Image? mapsFor(
    Object key, {
    required Size size,
    required double pixelRatio,
    required void Function(Canvas canvas, Rect area) bake,
  }) {
    if (key == _baked) return _maps;
    _discard();
    final sheet = size * _Sheet.tilesAcross;
    final isSettled = key == _wanted;
    _wanted = key;
    if (!isSettled || !_fits(sheet * pixelRatio)) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    bake(canvas, Offset.zero & sheet);
    final picture = recorder.endRecording();
    try {
      _maps = picture.toImageSync(
        (sheet.width * pixelRatio).ceil(),
        (sheet.height * pixelRatio).ceil(),
      );
    } finally {
      picture.dispose();
    }
    _baked = key;
    return _maps;
  }

  /// The size of a sheet of [maps] in logical pixels.
  static Size sizeOf(ui.Image maps, double pixelRatio) {
    return Size(maps.width / pixelRatio, maps.height / pixelRatio);
  }

  /// Releases the baked sheet.
  void dispose() => _discard();

  void _discard() {
    _maps?.dispose();
    _maps = null;
    _baked = null;
  }

  static bool _fits(Size pixels) {
    return !pixels.isEmpty && pixels.longestSide <= _Sheet.longestSide;
  }
}

class _Sheet {
  static const tilesAcross = 2.0;
  static const longestSide = 4096.0;
}
