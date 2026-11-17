import 'package:flutter/widgets.dart';
import 'package:kiss_physical/src/light/physical_light.dart';

/// Shifts [child] as the device is tilted, as though it floats above the
/// screen, by following the sway of the nearest [PhysicalLight].
///
/// A layer above the screen moves the opposite way to one beneath it, such
/// as the sockets of a `PhysicalPegboard`. Touches follow [child] to where
/// it is drawn.
///
/// [child] keeps its own layer, so a change of tilt moves that layer and
/// never rebuilds or repaints [child].
class PhysicalParallaxLayer extends StatelessWidget {
  /// Creates a layer that floats [height] above the screen.
  const PhysicalParallaxLayer({
    required this.child,
    this.height = defaultHeight,
    super.key,
  });

  /// A height suited to a foreground layer of controls that float over
  /// the content.
  static const defaultHeight = 20.0;

  /// How far above the screen [child] appears to float, in logical pixels.
  /// It shifts by this much per unit of [PhysicalLight.sway]. Zero keeps it
  /// still.
  final double height;

  /// What floats above the screen.
  final Widget child;

  /// Where a layer floating [height] above the screen is drawn for [sway].
  static Offset shiftFor(Offset sway, double height) => sway * -height;

  @override
  Widget build(BuildContext context) {
    final sway = PhysicalLight.swayOf(context);
    return ListenableBuilder(
      listenable: sway,
      builder: (context, child) => Transform.translate(
        offset: shiftFor(sway.value, height),
        child: child,
      ),
      child: RepaintBoundary(child: child),
    );
  }
}
