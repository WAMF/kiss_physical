import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/light/light_vector.dart';
import 'package:kiss_physical/src/light/physical_light.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/shader/physical_shader_brush.dart';
import 'package:kiss_physical/src/shader/shader_programs.dart';

/// A flat panel behind [child], covered by a regular grid of small round
/// sockets that are shaded by the nearest [PhysicalLight], with a soft wash
/// of light across the panel that leans towards it.
///
/// The whole board is drawn by one analytic fragment shader in its own
/// layer, so a change of light repaints only that layer and never rebuilds
/// or repaints [child]. Until the shader is loaded the panel is flat.
///
/// With [scrollsWithContent], the sockets slide with any vertical scrolling
/// inside [child], so content and panel move as one body. The wash is
/// lighting and stays where it is.
class PhysicalPegboard extends StatefulWidget {
  /// Creates a pegboard panel of [color] behind [child].
  const PhysicalPegboard({
    required this.color,
    required this.child,
    this.grid = const PegboardGrid(),
    this.material = PhysicalMaterial.peg,
    this.washStrength = defaultWashStrength,
    this.scrollsWithContent = false,
    this.depth = 0,
    super.key,
  }) : assert(
          washStrength >= 0 && washStrength <= 1,
          'washStrength must be in [0, 1]',
        );

  /// How much the wash lightens the panel where it is brightest.
  static const defaultWashStrength = 0.075;

  /// Colour of the panel the sockets are pressed into.
  final Color color;

  /// What sits on the panel.
  final Widget child;

  /// Spacing and size of the sockets.
  final PegboardGrid grid;

  /// Shape and finish of one socket. Only the roughness, specular tint and
  /// relief apply: a socket is always domed across its whole width.
  final PhysicalMaterial material;

  /// How much the wash lightens the panel where it is brightest, from 0
  /// (none) to 1 (white).
  final double washStrength;

  /// Whether the sockets move with vertical scrolling inside [child].
  final bool scrollsWithContent;

  /// How far beneath [child] the panel appears to lie, in logical pixels.
  /// As the device is tilted the sockets shift by this much per unit of
  /// [PhysicalLight.sway], which reads as parallax. Zero keeps them still.
  final double depth;

  @override
  State<PhysicalPegboard> createState() => _PhysicalPegboardState();
}

class _PhysicalPegboardState extends State<PhysicalPegboard> {
  final _travel = PegboardTravel();

  @override
  void didUpdateWidget(PhysicalPegboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.scrollsWithContent) _travel.reset();
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    _travel.follow(notification);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: _PegboardLayer(
            color: widget.color,
            grid: widget.grid,
            material: widget.material,
            washStrength: widget.washStrength,
            depth: widget.depth,
            travel: _travel,
          ),
        ),
        if (widget.scrollsWithContent)
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          )
        else
          widget.child,
      ],
    );
  }
}

/// How far the content over a [PhysicalPegboard] has scrolled down, in
/// logical pixels, summed over every vertical scrollable inside it.
class PegboardTravel extends ValueNotifier<double> {
  /// Creates a travel at rest.
  PegboardTravel() : super(0);

  /// Adds the movement reported by [notification], if it moved content.
  void follow(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return;
    final delta = notification.scrollDelta;
    if (delta != null) move(delta, notification.metrics.axisDirection);
  }

  /// Adds a scroll of [delta] in a scrollable that grows towards
  /// [direction]. Horizontal scrolling leaves the sockets where they are.
  void move(double delta, AxisDirection direction) {
    switch (direction) {
      case AxisDirection.down:
        value += delta;
      case AxisDirection.up:
        value -= delta;
      case AxisDirection.left:
      case AxisDirection.right:
        return;
    }
  }

  /// Returns the sockets to where they rest.
  void reset() => value = 0;
}

/// Describes where the sockets of a [PhysicalPegboard] sit.
@immutable
class PegboardGrid {
  /// Creates a grid of sockets [pitch] apart.
  const PegboardGrid({
    this.pitch = defaultPitch,
    this.socketRadius = defaultSocketRadius,
  })  : assert(pitch > 0, 'pitch must be positive'),
        assert(
          socketRadius >= 0 && socketRadius <= pitch / 2,
          'sockets must fit within their cell',
        );

  /// Puts about 27 sockets across the width of a handset.
  static const defaultPitch = 15.0;

  /// Keeps the socket a sixth of its cell, as on the launch film's panel.
  static const defaultSocketRadius = 2.4;

  /// Distance in logical pixels between the centres of neighbouring sockets.
  final double pitch;

  /// Radius in logical pixels of one socket.
  final double socketRadius;

  /// How many whole sockets fit across [width].
  int columnsIn(double width) => width <= 0 ? 0 : width ~/ pitch;

  /// Where the first cell starts on both axes, so that the columns are
  /// centred across [width] and the top margin matches the side margins.
  double originFor(double width) => width <= 0 ? 0 : (width % pitch) / 2;

  /// Where the first row starts once content has scrolled down by [travel].
  ///
  /// The grid repeats every [pitch], so the result stays within one cell
  /// however far the content travels.
  double rowOriginFor(double width, double travel) =>
      (originFor(width) - travel) % pitch;

  /// Moves [origin] by [shift] logical pixels, wrapped to stay within one
  /// cell since the grid repeats every [pitch].
  double shifted(double origin, double shift) => (origin + shift) % pitch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PegboardGrid &&
          other.pitch == pitch &&
          other.socketRadius == socketRadius;

  @override
  int get hashCode => Object.hash(pitch, socketRadius);
}

class _PegboardLayer extends StatefulWidget {
  const _PegboardLayer({
    required this.color,
    required this.grid,
    required this.material,
    required this.washStrength,
    required this.depth,
    required this.travel,
  });

  final Color color;
  final PegboardGrid grid;
  final PhysicalMaterial material;
  final double washStrength;
  final double depth;
  final ValueListenable<double> travel;

  @override
  State<_PegboardLayer> createState() => _PegboardLayerState();
}

class _PegboardLayerState extends State<_PegboardLayer> {
  final _brush = PhysicalShaderBrush(ShaderPrograms.pegboard.whenLoaded);

  @override
  void dispose() {
    _brush.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PegboardPainter(
          color: widget.color,
          grid: widget.grid,
          material: widget.material,
          washStrength: widget.washStrength,
          depth: widget.depth,
          travel: widget.travel,
          direction: PhysicalLight.of(context),
          sway: PhysicalLight.swayOf(context),
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
          brush: _brush,
        ),
      ),
    );
  }
}

class _PegboardPainter extends CustomPainter {
  _PegboardPainter({
    required this.color,
    required this.grid,
    required this.material,
    required this.washStrength,
    required this.depth,
    required this.travel,
    required this.direction,
    required this.sway,
    required this.pixelRatio,
    required this.brush,
  }) : super(
          repaint: Listenable.merge(
            [direction, sway, travel, ShaderPrograms.pegboard.whenLoaded],
          ),
        );

  final Color color;
  final PegboardGrid grid;
  final PhysicalMaterial material;
  final double washStrength;
  final double depth;
  final ValueListenable<double> travel;
  final ValueListenable<Offset> direction;
  final ValueListenable<Offset> sway;
  final double pixelRatio;
  final PhysicalShaderBrush brush;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;

    if (!brush.isReady) {
      canvas.drawRect(bounds, Paint()..color = color);
      return;
    }

    final light = LightVector.towards(direction.value);
    final shift = sway.value * depth;
    brush.shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, color.r)
      ..setFloat(3, color.g)
      ..setFloat(4, color.b)
      ..setFloat(5, color.a)
      ..setFloat(6, light.x)
      ..setFloat(7, light.y)
      ..setFloat(8, light.z)
      ..setFloat(9, grid.pitch)
      ..setFloat(10, grid.socketRadius)
      ..setFloat(11, grid.shifted(grid.originFor(size.width), shift.dx))
      ..setFloat(
        12,
        grid.shifted(grid.rowOriginFor(size.width, travel.value), shift.dy),
      )
      ..setFloat(13, material.roughness)
      ..setFloat(14, material.specularTint)
      ..setFloat(15, material.relief)
      ..setFloat(16, washStrength)
      ..setFloat(17, pixelRatio);

    canvas.drawRect(bounds, brush.paint);
  }

  @override
  bool shouldRepaint(_PegboardPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.grid != grid ||
        oldDelegate.material != material ||
        oldDelegate.washStrength != washStrength ||
        oldDelegate.depth != depth ||
        oldDelegate.travel != travel ||
        oldDelegate.sway != sway ||
        oldDelegate.direction != direction ||
        oldDelegate.pixelRatio != pixelRatio;
  }
}
