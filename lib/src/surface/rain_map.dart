import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:kiss_physical/src/surface/rain_field.dart';

/// A picture of the water on a surface for the surface shader to read:
/// how much water there is at each point in red and how wet the trails of
/// running drops have left the surface in green.
///
/// Each drop adds a soft mound of water that is fullest at its middle and
/// fades to nothing well beyond its edge, and the shader takes the water's
/// edge to be wherever the total passes a level. So two drops that come
/// close reach for each other, join by a neck and become one body of water,
/// as real drops do, in place of two discs that overlap.
///
/// Each new picture is drawn over a faded copy of the last, so a trail
/// stays where its drop ran and dries out over a few seconds.
class RainMap {
  ui.Image? _latest;

  /// A map with no water on it, for surfaces that are dry.
  static final ui.Image dry = _draw(
    const Size.square(1),
    (canvas) => canvas.drawPaint(Paint()..color = _Ink.dry),
  );

  static final ui.Image _dome = _draw(
    const Size.square(_Dome.size),
    (canvas) => canvas.drawPaint(
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(_Dome.size / 2, _Dome.size / 2),
          _Dome.size / 2,
          [for (final stop in _Dome.stops) _Dome.waterAt(stop)],
          _Dome.stops,
        ),
    ),
  );

  /// Draws [drops] on a surface of [size], [seconds] after the last map.
  ui.Image render(Iterable<RainDrop> drops, Size size, double seconds) {
    final previous = _latest;
    final next = _draw(size, (canvas) {
      canvas.drawPaint(Paint()..color = _Ink.dry);
      if (previous != null) _drawFaded(canvas, previous, size, seconds);
      for (final drop in drops) {
        _drawDrop(canvas, drop);
      }
    });
    previous?.dispose();
    return _latest = next;
  }

  /// Releases the latest map.
  void dispose() {
    _latest?.dispose();
    _latest = null;
  }

  static void _drawFaded(
    Canvas canvas,
    ui.Image previous,
    Size size,
    double seconds,
  ) {
    final kept = math.exp(-seconds / _Trail.dryingSeconds);
    final fade = seconds > 0 ? _Trail.leastFade : 0.0;
    canvas.drawImageRect(
      previous,
      Offset.zero & Size(previous.width.toDouble(), previous.height.toDouble()),
      Offset.zero & size,
      Paint()
        ..colorFilter = ColorFilter.matrix(<double>[
          0, 0, 0, 0, 0, //
          0, kept, 0, 0, -fade,
          0, 0, 0, 0, 0,
          0, 0, 0, 1, 0,
        ]),
    );
  }

  static void _drawDrop(Canvas canvas, RainDrop drop) {
    if (drop.isRunning) {
      canvas.drawCircle(
        drop.position,
        drop.radius * _Trail.widthShare * _Trail.swellAt(drop.position),
        Paint()
          ..color = _Ink.wet
          ..blendMode = BlendMode.lighten,
      );
    }
    _drawMound(canvas, drop.position, drop.radius);
    for (final (link, point) in drop.wake.indexed) {
      final drawnOut = (point - drop.position).distance /
          (drop.radius * _Dome.fullyDrawnOut * (link + 1));
      _drawMound(
        canvas,
        point,
        drop.radius * _Dome.wake[link] * math.min(drawnOut, 1),
      );
    }
  }

  /// Adds the water of a drop of [radius] to what is already at [centre].
  static void _drawMound(Canvas canvas, Offset centre, double radius) {
    canvas.drawImageRect(
      _dome,
      const Rect.fromLTWH(0, 0, _Dome.size, _Dome.size),
      Rect.fromCircle(center: centre, radius: radius * _Dome.spread),
      Paint()
        ..blendMode = BlendMode.plus
        ..filterQuality = FilterQuality.low,
    );
  }

  static ui.Image _draw(Size size, void Function(Canvas canvas) draw) {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(
        math.max(size.width.ceil(), 1),
        math.max(size.height.ceil(), 1),
      );
    } finally {
      picture.dispose();
    }
  }
}

class _Ink {
  static const dry = Color(0xFF000000);
  static const wet = Color(0xFF00FF00);
}

class _Trail {
  static const dryingSeconds = 2.5;
  static const widthShare = 0.6;
  static const _swell = 0.3;
  static const _swellAcross = 0.31;
  static const _swellAlong = 0.23;

  /// How much wider or narrower than usual a trail is where it passes
  /// [position], so that it swells and pinches along its length.
  static double swellAt(Offset position) {
    final wave = math.sin(position.dx * _swellAcross) +
        math.sin(position.dy * _swellAlong);
    return 1 + _swell * wave / 2;
  }

  /// Taken off every fade, in 255ths, so a trail dries right out and does
  /// not stall on the last faint shade a byte can hold.
  static const leastFade = 0.6;
}

class _Dome {
  static const size = 64.0;

  /// How large the mound at each link of a drop's wake is, as a share of
  /// the drop's radius. They shrink away from the head, so its rear draws
  /// out to a point.
  static const wake = [0.66, 0.46, 0.3, 0.18];

  /// How far behind the head, in radii for each link along, a link must
  /// lie to be drawn at its full size. Links gathered up into a resting
  /// drop add nothing to it.
  static const fullyDrawnOut = 0.3;
  static final stops = Float32List.fromList(
    [0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1],
  );

  /// The most water one drop adds, at its middle. The shader's own figure
  /// for the same thing must match it.
  static const fullest = 0.75;

  /// How far a drop's mound reaches beyond the drop itself: the mound falls
  /// to the level the shader takes as the water's edge at the drop's own
  /// radius.
  static const spread = 1.65;

  /// How much water a drop adds at [share] of the way out across its mound,
  /// written into the red channel.
  static Color waterAt(double share) {
    final fallOff = 1 - share * share;
    return Color.from(
      alpha: 1,
      red: fullest * fallOff * fallOff,
      green: 0,
      blue: 0,
    );
  }
}

/// The rain on one surface: its drops and the map drawn from them.
class SurfaceRain {
  /// The drops themselves.
  final field = RainField();
  final _map = RainMap();
  Size _size = Size.zero;
  double _undrawnSeconds = 0;

  /// Whether any drops are on the surface.
  bool get hasWater => !field.isEmpty;

  /// Moves the rain on by [seconds]. Nothing happens until the surface has
  /// been painted once and its size is known.
  void advance(
    double seconds, {
    required Offset gravity,
    required double rain,
    required double slip,
  }) {
    if (_size.isEmpty) return;
    field.advance(
      seconds,
      size: _size,
      gravity: gravity,
      rain: rain,
      slip: slip,
    );
    _undrawnSeconds += seconds;
  }

  /// The map of the rain as it now stands on a surface of [size].
  ui.Image mapFor(Size size) {
    _size = size;
    final map = _map.render(field.drops, size, _undrawnSeconds);
    _undrawnSeconds = 0;
    return map;
  }

  /// Releases the map drawn from the drops.
  void dispose() => _map.dispose();
}
