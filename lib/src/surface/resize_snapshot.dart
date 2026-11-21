import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// Spares a surface from being drawn afresh on every frame while it is
/// changing size, as it does when it flies between two screens.
///
/// A surface at rest is drawn directly. Once its size starts to change, it
/// is drawn once into a picture, and the following frames stretch that
/// picture to the new size instead. The picture is taken again whenever it
/// would be stretched too far to pass for the real thing, and it is only
/// ever stretched evenly: a surface that is changing shape, such as a bar
/// growing longer, is always drawn directly.
///
/// Listeners are told when a stretched frame may have been the last of a
/// resize, so that the surface can be drawn properly once it comes to rest.
class ResizeSnapshot extends ChangeNotifier {
  ui.Image? _picture;
  Size _pictureOf = Size.zero;
  Rect _pictureArea = Rect.zero;
  Object? _look;
  Size? _lastSize;
  bool _isAwaitingRest = false;
  bool _isDisposed = false;

  /// Draws a surface of [size] onto [canvas].
  ///
  /// [draw] paints the surface directly, filling [area], which may reach
  /// beyond the surface for its shadow. [look] holds everything other than
  /// size that changes what [draw] paints, so that a picture taken of one
  /// look is never shown for another.
  void paint(
    Canvas canvas, {
    required Size size,
    required Rect area,
    required double pixelRatio,
    required Object look,
    required void Function(Canvas canvas) draw,
  }) {
    final before = _lastSize;
    _lastSize = size;
    final isResizing = before != null && before != size;
    final canStandIn = isResizing &&
        !_isReshaped(from: before, to: size) &&
        _fits(area.size * pixelRatio);
    if (!canStandIn) {
      _discard();
      draw(canvas);
      return;
    }

    if (!_canStretchTo(size, look)) {
      _take(size: size, area: area, pixelRatio: pixelRatio, draw: draw);
      _look = look;
    }
    final picture = _picture!;
    final scale = size.width / _pictureOf.width;
    canvas.drawImageRect(
      picture,
      Offset.zero & Size(picture.width.toDouble(), picture.height.toDouble()),
      Rect.fromLTRB(
        _pictureArea.left * scale,
        _pictureArea.top * scale,
        _pictureArea.right * scale,
        _pictureArea.bottom * scale,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
    _redrawAtRest();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _discard();
    super.dispose();
  }

  bool _canStretchTo(Size size, Object look) {
    if (_picture == null || look != _look) return false;
    final widthScale = size.width / _pictureOf.width;
    final heightScale = size.height / _pictureOf.height;
    final isEven = (widthScale / heightScale - 1).abs() <= _Stretch.unevenness;
    final isClose =
        widthScale <= _Stretch.furthest && widthScale >= 1 / _Stretch.furthest;
    return isEven && isClose;
  }

  /// Whether one side kept its length while the other changed, as when a
  /// bar grows longer. However small such a step is, a picture stretched to
  /// it would drag the surface's texture along with the moving edge.
  static bool _isReshaped({required Size from, required Size to}) {
    return (from.width == to.width) != (from.height == to.height);
  }

  void _take({
    required Size size,
    required Rect area,
    required double pixelRatio,
    required void Function(Canvas canvas) draw,
  }) {
    _discard();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..translate(-area.left, -area.top);
    draw(canvas);
    final recorded = recorder.endRecording();
    try {
      _picture = recorded.toImageSync(
        (area.width * pixelRatio).ceil(),
        (area.height * pixelRatio).ceil(),
      );
    } finally {
      recorded.dispose();
    }
    _pictureOf = size;
    _pictureArea = area;
  }

  /// Asks for one more frame after this one. If the size has stopped
  /// changing by then, that frame draws the surface directly.
  void _redrawAtRest() {
    if (_isAwaitingRest) return;
    _isAwaitingRest = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _isAwaitingRest = false;
      if (!_isDisposed) notifyListeners();
    });
  }

  void _discard() {
    _picture?.dispose();
    _picture = null;
    _look = null;
  }

  static bool _fits(Size pixels) {
    return !pixels.isEmpty && pixels.longestSide <= _Stretch.longestSide;
  }
}

class _Stretch {
  /// How much larger or smaller than it was taken a picture may be shown.
  static const furthest = 1.2;

  /// How far width and height may differ in their stretch and still count
  /// as the same shape.
  static const unevenness = 0.01;

  /// The longest side, in device pixels, worth keeping a picture of.
  static const longestSide = 4096.0;
}
