import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/light/light_vector.dart';
import 'package:kiss_physical/src/light/physical_light.dart';
import 'package:kiss_physical/src/light/sky_light.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/shader/physical_shader_brush.dart';
import 'package:kiss_physical/src/shader/shader_programs.dart';
import 'package:kiss_physical/src/surface/rain_map.dart';
import 'package:kiss_physical/src/text/glyph_map.dart';

/// Lettering made of a [PhysicalMaterial]: every stroke has a rounded
/// shoulder that catches the nearest [PhysicalLight], and raised lettering
/// casts a shadow.
///
/// The material's finish, relief and elevation shape the letters. A
/// positive relief embosses them and a negative one engraves them. Its
/// bevel is how wide the shoulder of a stroke is, held to a share of the
/// font size so that a stroke keeps its form. Its texture makes them wood,
/// metal, plastic, stone or marble, worn as the texture says, and its
/// decals put dew on them. Its vessel and effects are not drawn.
///
/// Suited to headings and numerals. Small body text has strokes too thin to
/// shape and reads better as ordinary `Text`.
class PhysicalText extends StatelessWidget {
  /// Creates lettering that reads [data] in [color] and [material].
  const PhysicalText(
    this.data, {
    required this.color,
    this.material = PhysicalMaterial.satin,
    this.style,
    this.textAlign,
    this.maxLines,
    super.key,
  });

  /// What the lettering reads.
  final String data;

  /// The colour of the letters.
  final Color color;

  /// How the letters are shaped and how they catch the light.
  final PhysicalMaterial material;

  /// The style of the lettering, merged over the default text style. Its
  /// own colour is ignored in favour of [color].
  final TextStyle? style;

  /// How the lines are aligned across the width given.
  final TextAlign? textAlign;

  /// The most lines to show, beyond which the lettering ends in an ellipsis.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    return Semantics(
      label: data,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) => _Lettering(
            data: data,
            color: color,
            material: material,
            style: defaults.style.merge(style).copyWith(color: _Glyph.ink),
            textAlign: textAlign ?? defaults.textAlign ?? TextAlign.start,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: maxLines ?? defaults.maxLines,
            maxWidth: constraints.maxWidth,
          ),
        ),
      ),
    );
  }
}

class _Lettering extends StatefulWidget {
  const _Lettering({
    required this.data,
    required this.color,
    required this.material,
    required this.style,
    required this.textAlign,
    required this.textDirection,
    required this.textScaler,
    required this.maxLines,
    required this.maxWidth,
  });

  final String data;
  final Color color;
  final PhysicalMaterial material;
  final TextStyle style;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final int? maxLines;
  final double maxWidth;

  @override
  State<_Lettering> createState() => _LetteringState();
}

class _LetteringState extends State<_Lettering> {
  final _brush = PhysicalShaderBrush();
  final _map = GlyphMap();
  late TextPainter _laidOut = _layOut();

  @override
  void didUpdateWidget(_Lettering oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_readsAs(oldWidget)) return;
    _laidOut.dispose();
    _laidOut = _layOut();
    _map.clear();
  }

  @override
  void dispose() {
    _laidOut.dispose();
    _map.dispose();
    _brush.dispose();
    super.dispose();
  }

  bool _readsAs(_Lettering other) {
    return other.data == widget.data &&
        other.style == widget.style &&
        other.textAlign == widget.textAlign &&
        other.textDirection == widget.textDirection &&
        other.textScaler == widget.textScaler &&
        other.maxLines == widget.maxLines &&
        other.maxWidth == widget.maxWidth;
  }

  TextPainter _layOut() {
    return TextPainter(
      text: TextSpan(text: widget.data, style: widget.style),
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      textScaler: widget.textScaler,
      maxLines: widget.maxLines,
      ellipsis: widget.maxLines == null ? null : _Glyph.ellipsis,
    )..layout(maxWidth: widget.maxWidth);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.textScaler.scale(
      widget.style.fontSize ?? _Glyph.defaultFontSize,
    );
    final kind = _Glyph.programOf(widget.material);
    _brush.program = ShaderPrograms.lettering(kind).whenLoaded;
    return RepaintBoundary(
      child: CustomPaint(
        size: _laidOut.size,
        painter: _LetteringPainter(
          lettering: _laidOut,
          color: widget.color,
          material: widget.material,
          shoulder: math.min(
            widget.material.bevel,
            fontSize * _Glyph.widestShoulder,
          ),
          direction: PhysicalLight.of(context),
          tone: PhysicalLight.toneOf(context),
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
          isPlain: kind == SurfaceProgram.plain,
          brush: _brush,
          map: _map,
        ),
      ),
    );
  }
}

class _LetteringPainter extends CustomPainter {
  _LetteringPainter({
    required this.lettering,
    required this.color,
    required this.material,
    required this.shoulder,
    required this.direction,
    required this.tone,
    required this.pixelRatio,
    required this.isPlain,
    required this.brush,
    required this.map,
  }) : super(repaint: Listenable.merge([direction, tone, brush.program]));

  final TextPainter lettering;
  final Color color;
  final PhysicalMaterial material;

  /// How wide the rounded shoulder of a stroke is.
  final double shoulder;
  final ValueListenable<Offset> direction;
  final ValueListenable<LightTone> tone;
  final double pixelRatio;

  /// Whether the letters are only a lit shape, which the lean program
  /// draws, or have a texture, wear or dew that take the full one.
  final bool isPlain;
  final PhysicalShaderBrush brush;
  final GlyphMap map;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (!brush.isReady) {
      _paintFlat(canvas, size);
      return;
    }
    final softness = math.max(shoulder * _Glyph.softnessShare, _Glyph.sharpest);
    final reach = GlyphMap.reachOf(
      softness: softness,
      elevation: math.max(material.elevation, 0),
    );
    final area = (Offset.zero & size).inflate(reach);
    final glyphs = map.imageOf(
      lettering,
      softness: softness,
      reach: reach,
      pixelRatio: pixelRatio,
    );
    if (isPlain) {
      _configure(brush.shader, area: area, softness: softness, glyphs: glyphs);
    } else {
      _configureLayered(
        brush.shader,
        size: size,
        reach: reach,
        softness: softness,
        glyphs: glyphs,
      );
    }
    canvas.drawRect(area, brush.paint);
  }

  /// Draws the letters in their colour alone, while there is no program to
  /// light them with.
  void _paintFlat(Canvas canvas, Size size) {
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
    );
    lettering.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _configure(
    ui.FragmentShader shader, {
    required Rect area,
    required double softness,
    required ui.Image glyphs,
  }) {
    final light = LightVector.towards(direction.value);
    final LightTone(:key, :fill) = tone.value;
    shader
      ..setFloat(0, area.width)
      ..setFloat(1, area.height)
      ..setFloat(2, area.left)
      ..setFloat(3, area.top)
      ..setFloat(4, color.r)
      ..setFloat(5, color.g)
      ..setFloat(6, color.b)
      ..setFloat(7, color.a)
      ..setFloat(8, light.x)
      ..setFloat(9, light.y)
      ..setFloat(10, light.z)
      ..setFloat(11, material.roughness)
      ..setFloat(12, material.specularTint)
      ..setFloat(13, softness * _Glyph.slopeSpan)
      ..setFloat(14, material.relief)
      ..setFloat(15, math.max(material.elevation, 0))
      ..setFloat(16, pixelRatio)
      ..setFloat(17, light.z)
      ..setFloat(18, key.red)
      ..setFloat(19, key.green)
      ..setFloat(20, key.blue)
      ..setFloat(21, fill.red)
      ..setFloat(22, fill.green)
      ..setFloat(23, fill.blue)
      ..setImageSampler(0, glyphs);
  }

  /// Sets up the full surface program, which takes the letters for its
  /// outline where a body gives the radii of its corners. Everything after
  /// the texture, wear and dew is left at nothing: the letters are not
  /// rained on, burning, glowing or glass.
  void _configureLayered(
    ui.FragmentShader shader, {
    required Size size,
    required double reach,
    required double softness,
    required ui.Image glyphs,
  }) {
    final light = LightVector.towards(direction.value);
    final LightTone(:key, :fill) = tone.value;
    final texture = material.texture;
    final body = texture.isPlain ? color : texture.naturalColor ?? color;
    final second = texture.secondColorOn(body);
    final patina = texture.patinaColorOn(body);
    final figure = texture.figure;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, -reach)
      ..setFloat(3, -reach)
      ..setFloat(4, softness)
      ..setFloat(5, softness * _Glyph.slopeSpan)
      ..setFloat(6, body.r)
      ..setFloat(7, body.g)
      ..setFloat(8, body.b)
      ..setFloat(9, color.a)
      ..setFloat(10, light.x)
      ..setFloat(11, light.y)
      ..setFloat(12, light.z)
      ..setFloat(13, material.roughness)
      ..setFloat(14, material.specularTint)
      ..setFloat(15, softness / _Glyph.softnessShare)
      ..setFloat(16, _Glyph.crown)
      ..setFloat(17, material.relief)
      ..setFloat(18, math.max(material.elevation, 0))
      ..setFloat(19, pixelRatio)
      ..setFloat(20, _Glyph.notAnOverlay)
      ..setFloat(21, light.z)
      ..setFloat(22, key.red)
      ..setFloat(23, key.green)
      ..setFloat(24, key.blue)
      ..setFloat(25, fill.red)
      ..setFloat(26, fill.green)
      ..setFloat(27, fill.blue)
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
      ..setFloat(47, material.decals.dew);
    for (var at = _Glyph.firstUnused; at < _Glyph.floatCount; at++) {
      shader.setFloat(at, 0);
    }
    shader
      ..setImageSampler(0, RainMap.dry)
      ..setImageSampler(1, RainMap.dry)
      ..setImageSampler(2, glyphs);
  }

  @override
  bool shouldRepaint(_LetteringPainter oldDelegate) {
    return oldDelegate.isPlain != isPlain ||
        oldDelegate.lettering != lettering ||
        oldDelegate.color != color ||
        oldDelegate.material != material ||
        oldDelegate.shoulder != shoulder ||
        oldDelegate.direction != direction ||
        oldDelegate.tone != tone ||
        oldDelegate.pixelRatio != pixelRatio;
  }
}

class _Glyph {
  /// The first of the surface program's numbers that lettering has no use
  /// for: its rain, effects, baking and vessel. Each is set to nothing by
  /// hand, since not every platform starts a shader's numbers at nothing.
  static const firstUnused = 48;

  /// How many numbers the surface program takes in all.
  static const floatCount = 77;

  /// Lettering is not domed across its whole block as a body is across its
  /// face.
  static const crown = 0.0;
  static const notAnOverlay = 0.0;

  /// The program that draws lettering of [material]: what a body of its
  /// texture and decals would take, whatever else the material has.
  static SurfaceProgram programOf(PhysicalMaterial material) {
    return SurfaceProgram.of(
      PhysicalMaterial(texture: material.texture, decals: material.decals),
    );
  }

  /// The colour the letters are laid out in, which the map then recolours.
  static const ink = Color(0xFFFFFFFF);
  static const ellipsis = '…';
  static const defaultFontSize = 14.0;

  /// The widest a stroke's shoulder may be, as a share of the font size.
  static const widestShoulder = 0.1;

  /// How much of a shoulder's width the letters are blurred by: a blur
  /// rises from a half at the edge of a stroke to one about twice its own
  /// softness inside.
  static const softnessShare = 0.5;

  /// The least the letters are blurred by, below which a shoulder is too
  /// narrow for a slope to be read from it.
  static const sharpest = 0.4;

  /// How far apart, in softnesses, the shader reads the two heights it
  /// takes a slope from.
  static const slopeSpan = 0.5;
}
