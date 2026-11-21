import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Lettering drawn into an image for the text shader to shape and light.
///
/// Red holds the letters as they are. Green holds them blurred, which the
/// shader reads as the rounded shoulder of each
/// stroke and as the shadow the lettering casts.
class GlyphMap {
  ui.Image? _image;
  _Drawn? _drawn;

  /// How far the map reaches past lettering blurred by [softness] and
  /// raised by [elevation], so that neither its shoulder nor its shadow is
  /// cut off.
  static double reachOf({required double softness, required double elevation}) {
    final reach = softness * _Reach.blurSpread + elevation * _Reach.shadowThrow;
    return reach.ceilToDouble() + _Reach.margin;
  }

  /// The size of the map of [lettering] that reaches [reach] past it.
  static Size sizeOf(TextPainter lettering, double reach) {
    return lettering.size + Offset(reach, reach) * 2;
  }

  /// Forgets the map, so the next [imageOf] draws it afresh. Call this when
  /// the lettering changes.
  void clear() {
    _image?.dispose();
    _image = null;
    _drawn = null;
  }

  /// The map of [lettering], which must be laid out and painted in opaque
  /// white, drawn afresh only when what it is asked for changes.
  ui.Image imageOf(
    TextPainter lettering, {
    required double softness,
    required double reach,
    required double pixelRatio,
  }) {
    final wanted = (softness: softness, reach: reach, pixelRatio: pixelRatio);
    final kept = _image;
    if (kept != null && _drawn == wanted) return kept;
    kept?.dispose();
    _drawn = wanted;
    return _image = _draw(lettering, wanted);
  }

  /// Releases the map.
  void dispose() => clear();

  static ui.Image _draw(TextPainter lettering, _Drawn wanted) {
    final size = sizeOf(lettering, wanted.reach) * wanted.pixelRatio;
    final bounds = Offset.zero & sizeOf(lettering, wanted.reach);
    final inset = Offset(wanted.reach, wanted.reach);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(wanted.pixelRatio)
      ..saveLayer(bounds, Paint()..colorFilter = _Ink.sharp);
    lettering.paint(canvas, inset);
    canvas
      ..restore()
      ..saveLayer(
        bounds,
        Paint()
          ..colorFilter = _Ink.soft
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: wanted.softness,
            sigmaY: wanted.softness,
            tileMode: TileMode.decal,
          )
          ..blendMode = BlendMode.plus,
      );
    lettering.paint(canvas, inset);
    canvas.restore();
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(size.width.ceil(), size.height.ceil());
    } finally {
      picture.dispose();
    }
  }
}

typedef _Drawn = ({double softness, double reach, double pixelRatio});

class _Ink {
  static const sharp = ColorFilter.mode(Color(0xFFFF0000), BlendMode.srcIn);
  static const soft = ColorFilter.mode(Color(0xFF00FF00), BlendMode.srcIn);
}

class _Reach {
  /// How many times its own softness a blur spreads before it fades out.
  static const blurSpread = 3.0;

  /// How far a shadow is thrown for each unit the lettering is raised,
  /// under the lowest light there is.
  static const shadowThrow = 3.5;
  static const margin = 1.0;
}
