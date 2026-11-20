import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/light/light_vector.dart';
import 'package:kiss_physical/src/light/physical_light.dart';
import 'package:kiss_physical/src/light/sky_light.dart';
import 'package:kiss_physical/src/material/physical_decals.dart';
import 'package:kiss_physical/src/material/physical_effect.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/material/physical_vessel.dart';
import 'package:kiss_physical/src/shader/physical_shader_brush.dart';
import 'package:kiss_physical/src/shader/shader_programs.dart';
import 'package:kiss_physical/src/surface/flow_drift.dart';
import 'package:kiss_physical/src/surface/liquid_slosh.dart';
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
  });

  final Color color;
  final PhysicalMaterial material;
  final BorderRadius borderRadius;
  final Animation<double>? press;
  final bool isOverlay;
  final bool isFaceCovered;

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

  /// The program the layered brushes were last given, which says which
  /// uniforms they take.
  SurfaceProgram _layered = SurfaceProgram.plain;
  final _bake = SurfaceBake();
  final _resize = ResizeSnapshot();
  final _seconds = ValueNotifier<double>(0);
  final _slosh = LiquidSlosh();
  final _drift = FlowDrift();
  final _bubbles = FlowDrift();
  final _rain = SurfaceRain();
  Duration _lastTick = Duration.zero;
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
  void dispose() {
    _clock.dispose();
    _rain.dispose();
    _seconds.dispose();
    _brush.dispose();
    _bakeBrush.dispose();
    _plainBrush.dispose();
    _bake.dispose();
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
    return !widget.isOverlay && (material.isAnimated || _rain.hasWater);
  }

  void _tick(Duration elapsed) {
    final material = widget.material;
    final sinceLast = _secondsIn(elapsed - _lastTick);
    final vessel = material.vessel;
    if (vessel != null && vessel.holdsLiquid) {
      final gravity = vessel.gravity ?? _world.value;
      _slosh.advance(sinceLast, gravity);
      _bubbles.advance(sinceLast, gravity);
    }
    final flame = material.effectOf(PhysicalEffectKind.flame);
    if (flame != null) {
      _drift.advance(
        sinceLast,
        flame.gravity ?? _world.value,
        whenFlat: PhysicalLight.upright.value * _Shape.flatDeviceLean,
      );
    }
    final falling = material.effectOf(PhysicalEffectKind.rain);
    _rain.advance(
      sinceLast,
      gravity: falling?.gravity ?? _world.value,
      rain: falling?.intensity ?? 0,
      slip: material.slip,
    );
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
    _layered = kind;
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
          direction: PhysicalLight.of(context),
          tone: PhysicalLight.toneOf(context),
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
          world: _world,
          seconds: _seconds,
          slosh: _slosh,
          drift: _drift,
          bubbles: _bubbles,
          rain: _rain,
          layered: _layered,
          brush: _brush,
          bakeBrush: _bakeBrush,
          plainBrush: _plainBrush,
          bake: _bake,
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
    required this.direction,
    required this.tone,
    required this.pixelRatio,
    required this.world,
    required this.seconds,
    required this.slosh,
    required this.drift,
    required this.bubbles,
    required this.rain,
    required this.layered,
    required this.brush,
    required this.bakeBrush,
    required this.plainBrush,
    required this.bake,
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
  final ValueListenable<Offset> direction;
  final ValueListenable<LightTone> tone;
  final double pixelRatio;

  /// The real world's gravity on the screen, for water, flames and liquid
  /// that are given none of their own. It is read as each frame is drawn
  /// and does not itself cause one.
  final ValueListenable<Offset> world;

  /// Time for animated decals, in seconds.
  final ValueListenable<double> seconds;

  /// Where the surface of a liquid effect has swung to.
  final LiquidSlosh slosh;

  /// Which way the flames of a fire effect stream and how far they have.
  final FlowDrift drift;

  /// How far the bubbles in a liquid have risen, and against which way.
  final FlowDrift bubbles;

  /// The drops of rain on the surface.
  final SurfaceRain rain;

  /// The program [brush] and [bakeBrush] draw with.
  final SurfaceProgram layered;
  final PhysicalShaderBrush brush;

  /// Draws the layers that can be kept from frame to frame into [bake].
  final PhysicalShaderBrush bakeBrush;

  /// Draws a body that [_isPlain] with the lean program made for it.
  final PhysicalShaderBrush plainBrush;
  final SurfaceBake bake;

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
        !rain.hasWater;
  }

  /// Whether the body has layers worth keeping: a plain one is cheap enough
  /// to draw whole every time.
  bool get _isWorthBaking {
    final decals = material.decals;
    final isGrown = decals.moss + decals.grass + decals.flowers > 0;
    return !isOverlay &&
        !decals.showHints &&
        material.vessel == null &&
        (!material.texture.isPlain || isGrown);
  }

  /// The kept texture, wear and growth of the body at rest, baked now if
  /// it has settled since it last changed.
  ui.Image? _bakedMaps(Size size, RRect outline) {
    if (!_isWorthBaking || !bakeBrush.isReady) return null;
    final decals = material.decals;
    final key = (
      size,
      pixelRatio,
      outline,
      color,
      material.texture,
      material.roughness,
      material.specularTint,
      material.bevel,
      material.crown,
      material.relief,
      decals.moss,
      decals.grass,
      decals.flowers,
      decals.flowerColor,
      decals.grass > 0 ? _growthGravity(decals) : Offset.zero,
    );
    return bake.mapsFor(
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
    final isLive = !isOverlay && !isBaking;
    final neon = isLive ? shaped.effectOf(PhysicalEffectKind.neon) : null;
    final flame = isLive ? shaped.effectOf(PhysicalEffectKind.flame) : null;
    final falling = isLive ? shaped.effectOf(PhysicalEffectKind.rain) : null;
    final vessel = isLive ? shaped.vessel : null;
    final glowing = neon ?? flame;
    final glow = glowing?.color ?? _Shape.glass;
    final glaze = vessel?.color ?? _Shape.glass;
    final liquidUp = slosh.surfaceUp;
    final body = texture.isPlain ? color : texture.naturalColor ?? color;
    final second = texture.secondColorOn(body);
    final patina = texture.patinaColorOn(body);
    final figure = texture.figure;
    final decals = shaped.decals;
    final isWatered = isLive;
    final isRainedOn = isLive && (falling != null || rain.hasWater);
    final petal = decals.flowerColor;
    final pull =
        isBaking ? _growthGravity(decals) : falling?.gravity ?? world.value;
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
      ..setFloat(50, pull.dx)
      ..setFloat(51, pull.dy)
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
      ..setFloat(60, (flame?.height ?? 0) * drift.rise)
      ..setFloat(61, vessel?.opacity ?? 0)
      ..setFloat(62, vessel?.fill ?? 0)
      ..setFloat(63, vessel?.density ?? 0)
      ..setFloat(64, drift.down.dx)
      ..setFloat(65, drift.down.dy)
      ..setFloat(66, liquidUp.dx)
      ..setFloat(67, liquidUp.dy)
      ..setFloat(68, slosh.agitation)
      ..setFloat(69, slosh.foam)
      ..setFloat(70, isRainedOn ? 1 : 0)
      ..setFloat(71, pass.index.toDouble())
      ..setFloat(72, bakedSize.width)
      ..setFloat(73, bakedSize.height)
      ..setFloat(
        74,
        flame == null ? 0 : shaped.flammability,
      )
      ..setFloat(75, flame?.scorchDepth ?? 0)
      ..setFloat(76, flame?.embers ?? 0)
      ..setFloat(77, drift.travelled.dx)
      ..setFloat(78, drift.travelled.dy)
      ..setFloat(79, _Drawn.bodyOf(vessel))
      ..setFloat(80, glaze.r)
      ..setFloat(81, glaze.g)
      ..setFloat(82, glaze.b)
      ..setFloat(83, bubbles.travelled.dx)
      ..setFloat(84, bubbles.travelled.dy)
      ..setImageSampler(0, isRainedOn ? rain.mapFor(size) : RainMap.dry)
      ..setImageSampler(1, maps ?? RainMap.dry);
    if (!layered.hasGrowth) return;
    shader
      ..setFloat(85, isOverlay ? 0 : decals.moss)
      ..setFloat(86, isOverlay ? 0 : decals.grass)
      ..setFloat(87, isOverlay ? 0 : decals.flowers)
      ..setFloat(88, petal.r)
      ..setFloat(89, petal.g)
      ..setFloat(90, petal.b);
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

  /// Growth is baked standing as it grew, so it does not swing about with
  /// the device.
  static Offset _growthGravity(PhysicalDecals decals) {
    return decals.gravity ?? PhysicalLight.upright.value;
  }

  @override
  bool shouldRepaint(_SurfacePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.material != material ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.press != press ||
        oldDelegate.isOverlay != isOverlay ||
        oldDelegate.isFaceCovered != isFaceCovered ||
        oldDelegate.direction != direction ||
        oldDelegate.tone != tone ||
        oldDelegate.world != world ||
        oldDelegate.pixelRatio != pixelRatio;
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
  static const _holdingLiquid = 2.0;

  /// A glowing body is drawn as neon alone; otherwise fire is drawn round
  /// the lit body.
  static double kindOf({PhysicalEffect? neon, PhysicalEffect? flame}) {
    if (neon != null) return _neon;
    return flame == null ? _lit : _burning;
  }

  static double bodyOf(PhysicalVessel? vessel) {
    if (vessel == null) return _solid;
    return vessel.holdsLiquid ? _holdingLiquid : _glass;
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
