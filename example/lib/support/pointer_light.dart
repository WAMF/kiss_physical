import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:kiss_physical/kiss_physical.dart';

/// Lights [child] from wherever the pointer is, for devices that cannot
/// feel how they are held.
///
/// Moving the pointer towards an edge carries the light there and sways the
/// depth layers as tilting a handset that way would.
class PointerLight extends StatefulWidget {
  const PointerLight({required this.tone, required this.child, super.key});

  /// The colours of the light.
  final ValueListenable<LightTone> tone;

  final Widget child;

  @override
  State<PointerLight> createState() => _PointerLightState();
}

class _PointerLightState extends State<PointerLight> {
  static const _lightReach = 1.6;
  static const _swayReach = 0.7;

  final _direction = ValueNotifier<Offset>(PhysicalLight.still.value);
  final _sway = ValueNotifier<Offset>(Offset.zero);

  void _follow(PointerEvent event, Size size) {
    final fromCentre = Offset(
      event.localPosition.dx / size.width - 0.5,
      event.localPosition.dy / size.height - 0.5,
    );
    _direction.value = fromCentre * _lightReach;
    _sway.value = fromCentre * _swayReach;
  }

  @override
  void dispose() {
    _direction.dispose();
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Listener(
        onPointerHover: (event) => _follow(event, constraints.biggest),
        onPointerMove: (event) => _follow(event, constraints.biggest),
        child: PhysicalLight(
          direction: _direction,
          tone: widget.tone,
          sway: _sway,
          child: widget.child,
        ),
      ),
    );
  }
}
