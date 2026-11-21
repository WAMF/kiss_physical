import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/light/physical_light.dart';
import 'package:kiss_physical/src/light/sky_light.dart';

/// Lights [child] from wherever the pointer is, for devices that cannot
/// feel how they are held: desktops and the web.
///
/// Moving the pointer towards an edge carries the light there and sways the
/// depth layers as tilting a handset that way would. A finger dragged
/// across the screen does the same. With reduced motion the light rests.
class PointerLight extends StatefulWidget {
  /// Creates a light that follows the pointer over [child].
  const PointerLight({required this.child, this.tone, super.key});

  /// The colours of the light, or null for white.
  final ValueListenable<LightTone>? tone;

  /// The subtree the light falls on.
  final Widget child;

  @override
  State<PointerLight> createState() => _PointerLightState();
}

class _PointerLightState extends State<PointerLight> {
  static const _lightReach = 1.6;
  static const _swayReach = 0.7;

  final _direction = ValueNotifier<Offset>(PhysicalLight.still.value);
  final _sway = ValueNotifier<Offset>(Offset.zero);
  bool _isResting = false;

  void _follow(PointerEvent event, Size size) {
    if (_isResting || size.isEmpty) return;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isResting = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_isResting) return;
    _direction.value = PhysicalLight.still.value;
    _sway.value = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: (event) => _follow(event, constraints.biggest),
        onPointerMove: (event) => _follow(event, constraints.biggest),
        child: PhysicalLight(
          direction: _direction,
          tone: widget.tone ?? PhysicalLight.neutralTone,
          sway: _sway,
          child: widget.child,
        ),
      ),
    );
  }
}
