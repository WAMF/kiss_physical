import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/material/physical_texture.dart';

/// The tap a body gives the hand when it is touched.
enum PhysicalHaptic {
  /// Nothing is felt.
  none,

  /// The tick of one step among many, as a held button repeats.
  tick,

  /// A light body giving way: plastic and plain finishes.
  light,

  /// A solid body: wood and metal.
  medium,

  /// A heavy body: stone and marble.
  heavy,
}

/// How a body moves and what the hand feels when it is pressed, which
/// follows from what it is made of.
///
/// Plastic is light and springs back with a bounce, wood is damped, metal
/// is stiff and rings a little, and stone is heavy and settles without
/// bouncing at all.
@immutable
class PhysicalFeel {
  /// Creates a feel from the springs that move the body and the tap it
  /// gives.
  const PhysicalFeel({
    required this.press,
    required this.release,
    this.haptic = PhysicalHaptic.light,
  });

  /// The feel of a body made of [material].
  factory PhysicalFeel.of(PhysicalMaterial material) {
    if (material.vessel != null) return _Feels.glass;
    final texture = material.texture;
    if (texture.isPlain) return _Feels.plastic;
    return switch (texture.substance) {
      PhysicalSubstance.plain || PhysicalSubstance.plastic => _Feels.plastic,
      PhysicalSubstance.wood => _Feels.wood,
      PhysicalSubstance.metal => _Feels.metal,
      PhysicalSubstance.stone || PhysicalSubstance.marble => _Feels.stone,
    };
  }

  /// The spring that carries the body down under the finger.
  final SpringDescription press;

  /// The spring that returns the body to rest when it is let go.
  final SpringDescription release;

  /// What the hand feels as the body goes down.
  final PhysicalHaptic haptic;

  /// This feel with nothing given to the hand.
  PhysicalFeel get silent {
    return PhysicalFeel(
      press: press,
      release: release,
      haptic: PhysicalHaptic.none,
    );
  }

  /// How close to its target, and how nearly still, a pressed body must be
  /// to count as settled.
  static const settled = Tolerance(distance: 0.002, velocity: 0.02);
}

class _Feels {
  static const _pressStiffness = 1800.0;
  static const _releaseStiffness = 600.0;
  static const _withoutBounce = 1.0;

  static final plastic = _feel(
    mass: 1,
    bounce: 0.5,
    haptic: PhysicalHaptic.light,
  );
  static final glass = _feel(
    mass: 0.8,
    bounce: 0.85,
    haptic: PhysicalHaptic.light,
  );
  static final wood = _feel(
    mass: 1.2,
    bounce: 0.8,
    haptic: PhysicalHaptic.medium,
  );
  static final metal = _feel(
    mass: 1.4,
    bounce: 0.62,
    haptic: PhysicalHaptic.medium,
  );
  static final stone = _feel(
    mass: 2,
    bounce: _withoutBounce,
    haptic: PhysicalHaptic.heavy,
  );

  /// A feel for a body of [mass], where [bounce] is the damping ratio of
  /// its return: 1 settles without passing rest and less springs past it.
  /// It goes down under the finger without bouncing, whatever it is.
  static PhysicalFeel _feel({
    required double mass,
    required double bounce,
    required PhysicalHaptic haptic,
  }) {
    return PhysicalFeel(
      press: SpringDescription.withDampingRatio(
        mass: mass,
        stiffness: _pressStiffness,
      ),
      release: SpringDescription.withDampingRatio(
        mass: mass,
        stiffness: _releaseStiffness,
        ratio: bounce,
      ),
      haptic: haptic,
    );
  }
}
