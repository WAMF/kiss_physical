import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/light/light_vector.dart';
import 'package:kiss_physical/src/light/physical_light.dart';
import 'package:kiss_physical/src/light/sky_light.dart';
import 'package:kiss_physical/src/shader/physical_shader.dart';
import 'package:kiss_physical/src/shader/physical_shader_brush.dart';

/// One dot of a [PhysicalDotGrid].
@immutable
class PhysicalDot {
  /// A bead standing proud of the panel.
  const PhysicalDot.bead(this.color) : isBead = true;

  /// An empty socket pressed into the panel.
  const PhysicalDot.socket(this.color) : isBead = false;

  /// The colour of the bead or of the socket.
  final Color color;

  /// Whether this is a bead standing proud, rather than an empty socket.
  final bool isBead;

  @override
  bool operator ==(Object other) =>
      other is PhysicalDot && other.color == color && other.isBead == isBead;

  @override
  int get hashCode => Object.hash(color, isBead);
}

/// A grid of small lit beads and sockets, shaded by the nearest
/// [PhysicalLight] and filling the space it is given.
///
/// The whole grid is drawn by one fragment shader in its own layer, however
/// many dots it holds, so a change of light costs a single draw and never
/// rebuilds a dot. Until the shader is loaded the dots are flat.
class PhysicalDotGrid extends StatefulWidget {
  /// Creates a grid of [columns] by [rows] cells holding [dots].
  const PhysicalDotGrid({
    required this.columns,
    required this.rows,
    required this.dots,
    this.dotInset = defaultDotInset,
    super.key,
  })  : assert(columns > 0 && rows > 0, 'the grid needs at least one cell'),
        assert(
          dots.length == columns * rows,
          'dots must hold one entry per cell',
        );

  /// A hairline gap between neighbouring dots.
  static const defaultDotInset = 1.0;

  /// How many cells the grid has across.
  final int columns;

  /// How many cells the grid has down.
  final int rows;

  /// The dot in each cell, column by column from the top of each: the cell
  /// in column c and row r is at `c * rows + r`. Null leaves a cell empty.
  final List<PhysicalDot?> dots;

  /// Gap in logical pixels between a dot and the edge of its cell.
  final double dotInset;

  @override
  State<PhysicalDotGrid> createState() => _PhysicalDotGridState();
}

class _PhysicalDotGridState extends State<PhysicalDotGrid> {
  final _brush = PhysicalShaderBrush(PhysicalShader.dotGrid);
  final _cells = ValueNotifier<ui.Image?>(null);
  int _encoding = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_encodeCells());
  }

  @override
  void didUpdateWidget(PhysicalDotGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isSame = oldWidget.columns == widget.columns &&
        oldWidget.rows == widget.rows &&
        listEquals(oldWidget.dots, widget.dots);
    if (!isSame) unawaited(_encodeCells());
  }

  /// Packs the dots into an image with one texel per cell, for the shader
  /// to read each cell's colour and kind from.
  Future<void> _encodeCells() async {
    final request = ++_encoding;
    final image = await _DotCells.encode(
      widget.dots,
      columns: widget.columns,
      rows: widget.rows,
    );
    if (!mounted || request != _encoding) {
      image.dispose();
      return;
    }
    _cells.value?.dispose();
    _cells.value = image;
  }

  @override
  void dispose() {
    _encoding++;
    _cells.value?.dispose();
    _cells.dispose();
    _brush.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _DotGridPainter(
          columns: widget.columns,
          rows: widget.rows,
          dots: widget.dots,
          dotInset: widget.dotInset,
          cells: _cells,
          direction: PhysicalLight.of(context),
          tone: PhysicalLight.toneOf(context),
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
          brush: _brush,
        ),
      ),
    );
  }
}

/// The image the shader reads the dots from.
class _DotCells {
  static const _channels = 4;
  static const _opaque = 255;

  /// Alpha that marks a socket: premultiplied colour at half strength.
  static const _socketAlpha = 128;

  static Future<ui.Image> encode(
    List<PhysicalDot?> dots, {
    required int columns,
    required int rows,
  }) {
    final pixels = Uint8List(columns * rows * _channels);
    for (var column = 0; column < columns; column++) {
      for (var row = 0; row < rows; row++) {
        final dot = dots[column * rows + row];
        if (dot == null) continue;
        final alpha = dot.isBead ? _opaque : _socketAlpha;
        final strength = alpha / _opaque;
        final offset = (row * columns + column) * _channels;
        pixels[offset] = _byte(dot.color.r * strength);
        pixels[offset + 1] = _byte(dot.color.g * strength);
        pixels[offset + 2] = _byte(dot.color.b * strength);
        pixels[offset + 3] = alpha;
      }
    }
    final decoded = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      columns,
      rows,
      ui.PixelFormat.rgba8888,
      decoded.complete,
    );
    return decoded.future;
  }

  static int _byte(double value) => (value * _opaque).round().clamp(0, _opaque);
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({
    required this.columns,
    required this.rows,
    required this.dots,
    required this.dotInset,
    required this.cells,
    required this.direction,
    required this.tone,
    required this.pixelRatio,
    required this.brush,
  }) : super(
          repaint: Listenable.merge(
            [cells, direction, tone, PhysicalShader.dotGrid],
          ),
        );

  final int columns;
  final int rows;
  final List<PhysicalDot?> dots;
  final double dotInset;
  final ValueListenable<ui.Image?> cells;
  final ValueListenable<Offset> direction;
  final ValueListenable<LightTone> tone;
  final double pixelRatio;
  final PhysicalShaderBrush brush;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final image = cells.value;
    if (!brush.isReady || image == null) {
      _paintFlat(canvas, size);
      return;
    }

    final light = LightVector.towards(direction.value);
    final LightTone(:key, :fill) = tone.value;
    brush.shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, light.x)
      ..setFloat(3, light.y)
      ..setFloat(4, light.z)
      ..setFloat(5, columns.toDouble())
      ..setFloat(6, rows.toDouble())
      ..setFloat(7, dotInset)
      ..setFloat(8, pixelRatio)
      ..setFloat(9, key.red)
      ..setFloat(10, key.green)
      ..setFloat(11, key.blue)
      ..setFloat(12, fill.red)
      ..setFloat(13, fill.green)
      ..setFloat(14, fill.blue)
      ..setImageSampler(0, image);

    canvas.drawRect(Offset.zero & size, brush.paint);
  }

  /// Draws the dots as plain discs while the shader is not available.
  void _paintFlat(Canvas canvas, Size size) {
    final cell = Size(size.width / columns, size.height / rows);
    final radius = cell.shortestSide / 2 - dotInset;
    if (radius <= 0) return;
    final paint = Paint();
    for (var column = 0; column < columns; column++) {
      for (var row = 0; row < rows; row++) {
        final dot = dots[column * rows + row];
        if (dot == null) continue;
        canvas.drawCircle(
          Offset((column + 0.5) * cell.width, (row + 0.5) * cell.height),
          radius,
          paint..color = dot.color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.dotInset != dotInset ||
        oldDelegate.direction != direction ||
        oldDelegate.tone != tone ||
        oldDelegate.pixelRatio != pixelRatio ||
        !listEquals(oldDelegate.dots, dots);
  }
}
