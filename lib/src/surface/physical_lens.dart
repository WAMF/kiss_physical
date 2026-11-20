import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/light/light_vector.dart';
import 'package:kiss_physical/src/light/physical_light.dart';
import 'package:kiss_physical/src/light/sky_light.dart';
import 'package:kiss_physical/src/shader/physical_shader_brush.dart';
import 'package:kiss_physical/src/shader/shader_programs.dart';

/// How a [PhysicalLens] bends and colours what is beneath it.
@immutable
class LensOptics {
  /// Creates the optics of a lens; the defaults give thick clear glass.
  const LensOptics({
    this.refraction = 0.7,
    this.rimWidth = 22,
    this.aberration = 0.3,
    this.tint = _Glass.clear,
    this.tintStrength = 0.06,
  })  : assert(refraction >= 0, 'refraction must not be negative'),
        assert(rimWidth > 0, 'rimWidth must be positive'),
        assert(
          aberration >= 0 && aberration <= 1,
          'aberration must be in [0, 1]',
        ),
        assert(
          tintStrength >= 0 && tintStrength <= 1,
          'tintStrength must be in [0, 1]',
        );

  /// How far the rim bends the view, as a share of [rimWidth]. At 0 the
  /// glass is a flat pane.
  final double refraction;

  /// Width in logical pixels of the rolled edge, where the bending happens.
  final double rimWidth;

  /// How far red and blue part at the rim, from 0 to 1.
  final double aberration;

  /// The colour of the glass.
  final Color tint;

  /// How strongly [tint] shows, from 0 (clear) to 1.
  final double tintStrength;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LensOptics &&
          other.refraction == refraction &&
          other.rimWidth == rimWidth &&
          other.aberration == aberration &&
          other.tint == tint &&
          other.tintStrength == tintStrength;

  @override
  int get hashCode =>
      Object.hash(refraction, rimWidth, aberration, tint, tintStrength);
}

/// Sets [child] under a slab of clear glass that bends the view of it at
/// the rim, as a thick lens does, and catches the nearest [PhysicalLight].
///
/// The glass refracts [child] itself: the child is drawn to a picture and a
/// shader redraws it through the lens. Until the shader has loaded, [child]
/// shows as it is.
class PhysicalLens extends StatelessWidget {
  /// Creates a lens over [child].
  const PhysicalLens({
    required this.child,
    this.optics = const LensOptics(),
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  /// What is seen through the glass.
  final Widget child;

  /// How the glass bends and colours [child].
  final LensOptics optics;

  /// The corner radii of the slab of glass.
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return _Lens(
      optics: optics,
      borderRadius: borderRadius,
      direction: PhysicalLight.of(context),
      tone: PhysicalLight.toneOf(context),
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      child: child,
    );
  }
}

class _Lens extends SingleChildRenderObjectWidget {
  const _Lens({
    required this.optics,
    required this.borderRadius,
    required this.direction,
    required this.tone,
    required this.pixelRatio,
    required super.child,
  });

  final LensOptics optics;
  final BorderRadius borderRadius;
  final ValueListenable<Offset> direction;
  final ValueListenable<LightTone> tone;
  final double pixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLens()..configure(this);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderLens renderObject) {
    renderObject.configure(this);
  }
}

class _RenderLens extends RenderProxyBox {
  final _brush = PhysicalShaderBrush(ShaderPrograms.lens.whenLoaded);
  _Lens? _lens;
  Listenable? _repaint;

  void configure(_Lens lens) {
    _lens = lens;
    _listenTo(
      Listenable.merge(
        [lens.direction, lens.tone, ShaderPrograms.lens.whenLoaded],
      ),
    );
    markNeedsPaint();
  }

  void _listenTo(Listenable repaint) {
    if (attached) _repaint?.removeListener(markNeedsPaint);
    _repaint = repaint;
    if (attached) repaint.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _brush.dispose();
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final lens = _lens;
    if (child == null || lens == null || size.isEmpty || !_brush.isReady) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    final lensLayer = ((layer as _LensLayer?) ?? _LensLayer())
      ..offset = offset
      ..size = size
      ..pixelRatio = lens.pixelRatio
      ..draw = _drawThroughLens;
    context.pushLayer(lensLayer, super.paint, Offset.zero);
    layer = lensLayer;
  }

  void _drawThroughLens(Canvas canvas, ui.Image backdrop) {
    final lens = _lens!;
    final bounds = Offset.zero & size;
    final outline = lens.borderRadius.toRRect(bounds).scaleRadii();
    final light = LightVector.towards(lens.direction.value);
    final key = lens.tone.value.key;
    final LensOptics(
      :refraction,
      :rimWidth,
      :aberration,
      :tint,
      :tintStrength
    ) = lens.optics;
    _brush.shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, outline.tlRadiusX)
      ..setFloat(3, outline.trRadiusX)
      ..setFloat(4, outline.brRadiusX)
      ..setFloat(5, outline.blRadiusX)
      ..setFloat(6, light.x)
      ..setFloat(7, light.y)
      ..setFloat(8, light.z)
      ..setFloat(9, refraction)
      ..setFloat(10, math.min(rimWidth, size.shortestSide / 2))
      ..setFloat(11, aberration)
      ..setFloat(12, tintStrength)
      ..setFloat(13, tint.r)
      ..setFloat(14, tint.g)
      ..setFloat(15, tint.b)
      ..setFloat(16, key.red)
      ..setFloat(17, key.green)
      ..setFloat(18, key.blue)
      ..setFloat(19, lens.pixelRatio)
      ..setImageSampler(0, backdrop);
    canvas.drawRect(bounds, _brush.paint);
  }
}

/// Draws its children to a picture, then hands that picture to [draw] to
/// be redrawn in their place.
class _LensLayer extends OffsetLayer {
  Size size = Size.zero;
  double pixelRatio = 1;
  void Function(Canvas canvas, ui.Image backdrop)? draw;
  ui.Picture? _drawn;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final backdrop = _childrenAsImage();
    final recorder = ui.PictureRecorder();
    try {
      draw?.call(Canvas(recorder), backdrop);
    } finally {
      backdrop.dispose();
    }
    _drawn?.dispose();
    final drawn = _drawn = recorder.endRecording();
    builder.addPicture(offset, drawn);
  }

  ui.Image _childrenAsImage() {
    final scene = ui.SceneBuilder()
      ..pushTransform(
        Matrix4.diagonal3Values(pixelRatio, pixelRatio, 1).storage,
      );
    addChildrenToScene(scene);
    scene.pop();
    final built = scene.build();
    try {
      return built.toImageSync(
        (size.width * pixelRatio).ceil(),
        (size.height * pixelRatio).ceil(),
      );
    } finally {
      built.dispose();
    }
  }

  @override
  void dispose() {
    _drawn?.dispose();
    _drawn = null;
    super.dispose();
  }
}

class _Glass {
  static const clear = Color(0xFFE8F4F6);
}
