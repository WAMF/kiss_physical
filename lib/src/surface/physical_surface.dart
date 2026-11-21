import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/light/light_vector.dart';
import 'package:kiss_physical/src/light/physical_light.dart';
import 'package:kiss_physical/src/light/sky_light.dart';
import 'package:kiss_physical/src/material/physical_effect.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/material/physical_vessel.dart';
import 'package:kiss_physical/src/shader/physical_shader_brush.dart';
import 'package:kiss_physical/src/shader/shader_programs.dart';
import 'package:kiss_physical/src/surface/flow_drift.dart';
import 'package:kiss_physical/src/surface/rain_map.dart';
import 'package:kiss_physical/src/surface/resize_snapshot.dart';
import 'package:kiss_physical/src/surface/surface_bake.dart';

/// A solid, lit body behind [child]: a rounded slab, pill or disc whose
/// bevels, highlights and shadow follow the nearest [PhysicalLight].
///
/// The body is drawn by one analytic fragment shader in its own layer, so a
/// change of light repaints only that layer and never rebuilds or repaints
/// [child].
class PhysicalSurface extends StatelessWidget {
  /// Creates a lit body of [color] behind [child].
  const PhysicalSurface({
    required this.color,
    required this.child,
    this.material = PhysicalMaterial.satin,
    this.borderRadius = BorderRadius.zero,
    this.press,
    this.clipBehavior = Clip.none,
    this.isFaceCovered = false,
    this.textureAlignment = Alignment.center,
    super.key,
  });

  /// Radius that rounds the short sides completely, giving a pill or disc.
  static const stadium = BorderRadius.all(Radius.circular(_Shape.stadium));

  /// The base colour of the body, which the light shades and tints.
  final Color color;

  /// What sits on the face of the body.
  final Widget child;

  /// How the body is shaped and how it catches the light.
  final PhysicalMaterial material;

  /// The corner radii of the body; [stadium] gives a pill or disc.
  final BorderRadius borderRadius;

  /// How far the surface is pushed in, from 0 (resting) to 1 (pressed).
  final Animation<double>? press;

  /// How [child] is clipped to the outline.
  final Clip clipBehavior;

  /// Whether [child] hides the whole face behind something opaque, such as
  /// a photograph. Only the shadow around the body is then drawn, which
  /// spares lighting a face nobody can see.
  final bool isFaceCovered;

  /// The point of the body its texture is pinned to. The grain or veins
  /// there stay put while the body changes size, so a bar that grows from
  /// its start uncovers more of one texture when pinned to
  /// [AlignmentDirectional.centerStart], where pinned to its centre the
  /// texture would slide along as it grew.
  final AlignmentGeometry textureAlignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: _SurfaceLayer(
            color: color,
            material: material,
            borderRadius: borderRadius,
            press: press,
            isOverlay: false,
            isFaceCovered: isFaceCovered,
            textureAlignment: textureAlignment,
          ),
        ),
        if (clipBehavior == Clip.none)
          child
        else
          ClipRRect(
            borderRadius: borderRadius,
            clipBehavior: clipBehavior,
            child: child,
          ),
      ],
    );
  }
}

/// Lays a clear lens over [child], adding the highlights and edge shading
/// of a [PhysicalSurface] without hiding what is underneath.
///
/// Suited to photographs, which should look set under glass.
class PhysicalGlass extends StatelessWidget {
  /// Creates a clear lens over [child].
  const PhysicalGlass({
    required this.child,
    this.material = PhysicalMaterial.glass,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  /// What is seen under the glass.
  final Widget child;

  /// How the glass is shaped and how it catches the light.
  final PhysicalMaterial material;

  /// The corner radii of the glass.
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: _SurfaceLayer(
              color: _Shape.glass,
              material: material,
              borderRadius: borderRadius,
              press: null,
              isOverlay: true,
              isFaceCovered: false,
              textureAlignment: Alignment.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _SurfaceLayer extends StatefulWidget {
  const _SurfaceLayer({
    required this.color,
    required this.material,
    required this.borderRadius,
    required this.press,
    required this.isOverlay,
    required this.isFaceCovered,
    required this.textureAlignment,
  });

  final Color color;
  final PhysicalMaterial material;
  final BorderRadius borderRadius;
  final Animation<double>? press;
  final bool isOverlay;
  final bool isFaceCovered;
  final AlignmentGeometry textureAlignment;

  @override
  State<_SurfaceLayer> createState() => _SurfaceLayerState();
}

class _SurfaceLayerState extends State<_SurfaceLayer>
    with SingleTickerProviderStateMixin {
  final _brush = PhysicalShaderBrush();
  final _bakeBrush = PhysicalShaderBrush();
  final _plainBrush = PhysicalShaderBrush(
    ShaderPrograms.surface(SurfaceProgram.plain).whenLoaded,
  );

  final _motion = _Motion();
  final _resize = ResizeSnapshot();
  final _seconds = ValueNotifier<double>(0);
  Duration _lastTick = Duration.zero;

  /// Whether the user asked for reduced motion, which holds flames, rain
  /// and flicker still.
  bool _isStilled = false;
  ValueListenable<Offset> _world = PhysicalLight.upright;
  late final Ticker _clock = createTicker(_tick);

  @override
  void initState() {
    super.initState();
    _runClockWhileAnimated();
  }

  @override
  void didUpdateWidget(_SurfaceLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _runClockWhileAnimated();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isStilled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _runClockWhileAnimated();
  }

  @override
  void dispose() {
    _clock.dispose();
    _motion.dispose();
    _seconds.dispose();
    _brush.dispose();
    _bakeBrush.dispose();
    _plainBrush.dispose();
    _resize.dispose();
    super.dispose();
  }

  void _runClockWhileAnimated() {
    if (_isAnimated == _clock.isActive) return;
    if (_isAnimated) {
      _lastTick = Duration.zero;
      _clock.start();
    } else {
      _clock.stop();
    }
  }

  /// Whether anything on the surface is moving. Water already on it keeps
  /// running and drying after the rain stops.
  bool get _isAnimated {
    final material = widget.material;
    return !widget.isOverlay &&
        !_isStilled &&
        (material.isAnimated || _motion.hasWater);
  }

  void _tick(Duration elapsed) {
    final material = widget.material;
    final sinceLast = _secondsIn(elapsed - _lastTick);
    final flame = material.effectOf(PhysicalEffectKind.flame);
    if (flame != null) {
      _motion.drift.advance(
        sinceLast,
        flame.gravity ?? _world.value,
        whenFlat: PhysicalLight.upright.value * _Shape.flatDeviceLean,
      );
    }
    final falling = material.effectOf(PhysicalEffectKind.rain);
    if (falling != null || _motion.hasWater) {
      _motion.rain.advance(
        sinceLast,
        gravity: falling?.gravity ?? _world.value,
        rain: falling?.intensity ?? 0,
        slip: material.slip,
      );
    }
    _lastTick = elapsed;
    _seconds.value = _secondsIn(elapsed) % _Clock.wrapSeconds;
    if (!_isAnimated) _clock.stop();
  }

  /// Points the layered brushes at the program for [material]. A plain
  /// body keeps the program it had, which still draws any water left on it.
  void _useProgramOf(PhysicalMaterial material) {
    final kind = SurfaceProgram.of(material);
    if (kind == SurfaceProgram.plain) return;
    final program = ShaderPrograms.surface(kind).whenLoaded;
    _brush.program = program;
    _bakeBrush.program = program;
  }

  static double _secondsIn(Duration time) {
    return time.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  Widget build(BuildContext context) {
    _world = PhysicalLight.gravityOf(context);
    _useProgramOf(widget.material);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SurfacePainter(
          color: widget.color,
          material: widget.material,
          borderRadius: widget.borderRadius,
          press: widget.press,
          isOverlay: widget.isOverlay,
          isFaceCovered: widget.isFaceCovered,
          textureAlignment: widget.textureAlignment.resolve(
            Directionality.maybeOf(context),
          ),
          direction: PhysicalLight.of(context),
          tone: PhysicalLight.toneOf(context),
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
          world: _world,
          seconds: _seconds,
          motion: _motion,
          brush: _brush,
          bakeBrush: _bakeBrush,
          plainBrush: _plainBrush,
          resize: _resize,
        ),
      ),
    );
  }
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter({
    required this.color,
    required this.material,
    required this.borderRadius,
    required this.press,
    required this.isOverlay,
    required this.isFaceCovered,
    required this.textureAlignment,
    required this.direction,
    required this.tone,
    required this.pixelRatio,
    required this.world,
    required this.seconds,
    required this.motion,
    required this.brush,
    required this.bakeBrush,
    required this.plainBrush,
    required this.resize,
  }) : super(
          repaint: Listenable.merge([
            direction,
            tone,
            press,
            seconds,
            resize,
            brush.program,
            plainBrush.program,
          ]),
        );

  final Color color;
  final PhysicalMaterial material;
  final BorderRadius borderRadius;
  final Animation<double>? press;
  final bool isOverlay;
  final bool isFaceCovered;
  final Alignment textureAlignment;
  final ValueListenable<Offset> direction;
  final ValueListenable<LightTone> tone;
  final double pixelRatio;

  /// The real world's gravity on the screen, for water and flames
  /// that are given none of their own. It is read as each frame is drawn
  /// and does not itself cause one.
  final ValueListenable<Offset> world;

  /// Time for animated decals, in seconds.
  final ValueListenable<double> seconds;

  /// What moves on the surface by itself: flames, rain,
  /// and the layers kept from frame to frame.
  final _Motion motion;

  final PhysicalShaderBrush brush;

  /// Draws the layers that can be kept from frame to frame, to be baked.
  final PhysicalShaderBrush bakeBrush;

  /// Draws a body that [_isPlain] with the lean program made for it.
  final PhysicalShaderBrush plainBrush;

  /// Stands in for the shader while the surface is changing size.
  final ResizeSnapshot resize;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final outline = borderRadius.toRRect(bounds).scaleRadii();

    if (!brush.isReady && !(_isPlain && plainBrush.isReady)) {
      if (!isOverlay) canvas.drawRRect(outline, Paint()..color = color);
      return;
    }

    final pressed = press?.value ?? 0;
    final shaped = material.pressed(pressed);
    final area = isOverlay ? bounds : bounds.inflate(shaped.paintReach);
    resize.paint(
      canvas,
      size: size,
      area: area,
      pixelRatio: pixelRatio,
      look: (color, material, borderRadius, pressed, isOverlay, isFaceCovered),
      draw: (target) => _drawLit(target, size, outline, shaped, area),
    );
  }

  /// Lights the surface with the shader and draws it over [area].
  void _drawLit(
    Canvas canvas,
    Size size,
    RRect outline,
    PhysicalMaterial shaped,
    Rect area,
  ) {
    final paint = _litPaint(size, outline, shaped);
    canvas.save();
    if (isFaceCovered) {
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(area),
          Path()..addRRect(outline.deflate(_Shape.coveredFaceOverlap)),
        ),
      );
    }
    canvas
      ..drawRect(area, paint)
      ..restore();
  }

  /// The paint that lights the surface: the lean program for a plain body,
  /// the full one for a body with layers.
  Paint _litPaint(Size size, RRect outline, PhysicalMaterial shaped) {
    if (_isPlain && plainBrush.isReady) {
      _configureBody(
        plainBrush.shader,
        size: size,
        outline: outline,
        shaped: shaped,
        body: color,
      );
      return plainBrush.paint;
    }
    final maps = _bakedMaps(size, outline);
    _configure(
      brush.shader,
      size: size,
      outline: outline,
      shaped: shaped,
      pass: maps == null ? _Pass.whole : _Pass.relight,
      maps: maps,
    );
    return brush.paint;
  }

  /// Whether the body is only a lit shape, with nothing on it or in it that
  /// the lean program cannot draw.
  bool get _isPlain {
    if (isOverlay) return true;
    return material.texture.isPlain &&
        material.decals.isEmpty &&
        material.vessel == null &&
        material.effects.isEmpty &&
        !motion.hasWater;
  }

  /// Whether the body has layers worth keeping: a plain one is cheap enough
  /// to draw whole every time.
  bool get _isWorthBaking {
    return !isOverlay &&
        !material.decals.showHints &&
        material.vessel == null &&
        !material.texture.isPlain;
  }

  /// The kept texture and wear of the body at rest, baked now if
  /// it has settled since it last changed.
  ui.Image? _bakedMaps(Size size, RRect outline) {
    if (!_isWorthBaking || !bakeBrush.isReady) return null;
    final key = (
      size,
      pixelRatio,
      outline,
      color,
      textureAlignment,
      material.texture,
      material.roughness,
      material.specularTint,
      material.bevel,
      material.crown,
      material.relief,
    );
    return motion.bake.mapsFor(
      key,
      size: size,
      pixelRatio: pixelRatio,
      bake: (canvas, area) {
        _configure(
          bakeBrush.shader,
          size: size,
          outline: outline,
          shaped: material,
          pass: _Pass.bake,
        );
        canvas.drawRect(area, bakeBrush.paint);
      },
    );
  }

  void _configure(
    ui.FragmentShader shader, {
    required Size size,
    required RRect outline,
    required PhysicalMaterial shaped,
    required _Pass pass,
    ui.Image? maps,
  }) {
    final isBaking = pass == _Pass.bake;
    final texture = shaped.texture;
    final textureOrigin = Offset(
      textureAlignment.x * size.width / 2,
      textureAlignment.y * size.height / 2,
    );
    final isLive = !isOverlay && !isBaking;
    final neon = isLive ? shaped.effectOf(PhysicalEffectKind.neon) : null;
    final flame = isLive ? shaped.effectOf(PhysicalEffectKind.flame) : null;
    final falling = isLive ? shaped.effectOf(PhysicalEffectKind.rain) : null;
    final vessel = isLive ? shaped.vessel : null;
    final glowing = neon ?? flame;
    final glow = glowing?.color ?? _Shape.glass;
    final glaze = vessel?.color ?? _Shape.glass;
    final body = texture.isPlain ? color : texture.naturalColor ?? color;
    final second = texture.secondColorOn(body);
    final patina = texture.patinaColorOn(body);
    final figure = texture.figure;
    final decals = shaped.decals;
    final isWatered = isLive;
    final isRainedOn = isLive && (falling != null || motion.hasWater);
    final bakedSize =
        maps == null ? Size.zero : SurfaceBake.sizeOf(maps, pixelRatio);
    _configureBody(
      shader,
      size: size,
      outline: outline,
      shaped: shaped,
      body: body,
    );
    shader
      ..setFloat(28, texture.isPlain ? 0 : texture.substance.index.toDouble())
      ..setFloat(29, texture.scale)
      ..setFloat(30, texture.strength)
      ..setFloat(31, figure[0])
      ..setFloat(32, figure[1])
      ..setFloat(33, figure[2])
      ..setFloat(34, figure[3])
      ..setFloat(35, second.r)
      ..setFloat(36, second.g)
      ..setFloat(37, second.b)
      ..setFloat(38, patina.r)
      ..setFloat(39, patina.g)
      ..setFloat(40, patina.b)
      ..setFloat(41, texture.age)
      ..setFloat(42, texture.scratches)
      ..setFloat(43, texture.dents)
      ..setFloat(44, texture.scratchDirection)
      ..setFloat(45, texture.scratchSpread)
      ..setFloat(46, texture.scratchClustering)
      ..setFloat(47, isWatered ? decals.dew : 0)
      ..setFloat(48, falling?.intensity ?? 0)
      ..setFloat(49, isBaking ? 0 : seconds.value)
      ..setFloat(50, textureOrigin.dx)
      ..setFloat(51, textureOrigin.dy)
      ..setFloat(52, decals.showHints && isWatered ? 1 : 0)
      ..setFloat(53, _Drawn.kindOf(neon: neon, flame: flame))
      ..setFloat(54, glowing?.intensity ?? 0)
      ..setFloat(55, neon?.tube ?? 0)
      ..setFloat(
        56,
        neon?.flicker ?? flame?.turbulence ?? 0,
      )
      ..setFloat(57, glow.r)
      ..setFloat(58, glow.g)
      ..setFloat(59, glow.b)
      ..setFloat(60, (flame?.height ?? 0) * motion.drift.rise)
      ..setFloat(61, vessel?.opacity ?? 0)
      ..setFloat(62, motion.drift.down.dx)
      ..setFloat(63, motion.drift.down.dy)
      ..setFloat(64, isRainedOn ? 1 : 0)
      ..setFloat(65, pass.index.toDouble())
      ..setFloat(66, bakedSize.width)
      ..setFloat(67, bakedSize.height)
      ..setFloat(
        68,
        flame == null ? 0 : shaped.flammability,
      )
      ..setFloat(69, flame?.scorchDepth ?? 0)
      ..setFloat(70, flame?.embers ?? 0)
      ..setFloat(71, motion.drift.travelled.dx)
      ..setFloat(72, motion.drift.travelled.dy)
      ..setFloat(73, _Drawn.bodyOf(vessel))
      ..setFloat(74, glaze.r)
      ..setFloat(75, glaze.g)
      ..setFloat(76, glaze.b)
      ..setImageSampler(0, isRainedOn ? motion.rain.mapFor(size) : RainMap.dry)
      ..setImageSampler(1, maps ?? RainMap.dry);
  }

  /// Sets the shape, colour and light of the body, which both programs
  /// take first and in the same order.
  void _configureBody(
    ui.FragmentShader shader, {
    required Size size,
    required RRect outline,
    required PhysicalMaterial shaped,
    required Color body,
  }) {
    final light = LightVector.towards(direction.value);
    final LightTone(:key, :fill) = tone.value;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, outline.tlRadiusX)
      ..setFloat(3, outline.trRadiusX)
      ..setFloat(4, outline.brRadiusX)
      ..setFloat(5, outline.blRadiusX)
      ..setFloat(6, body.r)
      ..setFloat(7, body.g)
      ..setFloat(8, body.b)
      ..setFloat(9, color.a)
      ..setFloat(10, light.x)
      ..setFloat(11, light.y)
      ..setFloat(12, light.z)
      ..setFloat(13, shaped.roughness)
      ..setFloat(14, shaped.specularTint)
      ..setFloat(15, math.min(shaped.bevel, size.shortestSide / 2))
      ..setFloat(16, shaped.crown)
      ..setFloat(17, shaped.relief)
      ..setFloat(18, shaped.elevation)
      ..setFloat(19, pixelRatio)
      ..setFloat(20, isOverlay ? 1 : 0)
      ..setFloat(21, light.z)
      ..setFloat(22, key.red)
      ..setFloat(23, key.green)
      ..setFloat(24, key.blue)
      ..setFloat(25, fill.red)
      ..setFloat(26, fill.green)
      ..setFloat(27, fill.blue);
  }

  @override
  bool shouldRepaint(_SurfacePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.material != material ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.press != press ||
        oldDelegate.isOverlay != isOverlay ||
        oldDelegate.isFaceCovered != isFaceCovered ||
        oldDelegate.textureAlignment != textureAlignment ||
        oldDelegate.direction != direction ||
        oldDelegate.tone != tone ||
        oldDelegate.world != world ||
        oldDelegate.pixelRatio != pixelRatio;
  }
}

/// What moves on a surface by itself, each made only when it is first
/// needed, so that a plain body carries none of it.
class _Motion {
  /// Which way the flames of a fire stream and how far they have.
  late final drift = FlowDrift();

  SurfaceRain? _rain;
  SurfaceBake? _bake;

  /// The drops of rain on the surface.
  SurfaceRain get rain => _rain ??= SurfaceRain();

  /// The layers of the body kept from frame to frame.
  SurfaceBake get bake => _bake ??= SurfaceBake();

  /// Whether any rain is on the surface, without making rain to find out.
  bool get hasWater => _rain?.hasWater ?? false;

  void dispose() {
    _rain?.dispose();
    _bake?.dispose();
  }
}

/// Which part of its work the surface shader does in one drawing. The order
/// is the shader's own numbering.
enum _Pass { whole, bake, relight }

/// The shader's own numbers for how a body is drawn.
class _Drawn {
  static const _lit = 0.0;
  static const _neon = 1.0;
  static const _burning = 2.0;
  static const _solid = 0.0;
  static const _glass = 1.0;

  /// A glowing body is drawn as neon alone; otherwise fire is drawn round
  /// the lit body.
  static double kindOf({PhysicalEffect? neon, PhysicalEffect? flame}) {
    if (neon != null) return _neon;
    return flame == null ? _lit : _burning;
  }

  static double bodyOf(PhysicalVessel? vessel) {
    return vessel == null ? _solid : _glass;
  }
}

class _Clock {
  /// Keeps the time small enough for the shader to stay precise.
  static const wrapSeconds = 3600.0;
}

class _Shape {
  static const stadium = 10000.0;

  /// A lean towards the bottom of the screen that settles which way flames
  /// rise while the device lies too flat for gravity to say.
  static const flatDeviceLean = 0.1;
  static const glass = Color(0xFFFFFFFF);

  /// How far the drawn rim reaches under a covered face, so that no gap
  /// shows where the two meet.
  static const coveredFaceOverlap = 1.0;
}
