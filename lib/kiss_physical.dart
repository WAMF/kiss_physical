/// A physically lit UI kit: surfaces shaded by fragment programs under one
/// world light that follows the way the device is held.
///
/// Put a `WorldLight` at the root of the app, call
/// `PhysicalShader.precache` before the first frame, and build the interface
/// from `PhysicalSurface` bodies in a `PhysicalMaterial`.
library;

export 'src/components/physical_card.dart';
export 'src/components/physical_icon_button.dart';
export 'src/components/physical_panel.dart';
export 'src/components/physical_pill_button.dart';
export 'src/components/physical_progress_bar.dart';
export 'src/components/physical_segmented_control.dart';
export 'src/components/physical_slider.dart';
export 'src/components/physical_spinner.dart';
export 'src/components/physical_switch.dart';
export 'src/components/physical_text_field.dart';
export 'src/light/physical_light.dart';
export 'src/light/pointer_light.dart';
export 'src/light/sky_light.dart';
export 'src/material/physical_decals.dart';
export 'src/material/physical_effect.dart';
export 'src/material/physical_material.dart';
export 'src/material/physical_texture.dart';
export 'src/material/physical_vessel.dart';
export 'src/motion/hold_repeater.dart';
export 'src/motion/physical_feel.dart';
export 'src/motion/physical_haptics.dart';
export 'src/motion/physical_motion.dart';
export 'src/motion/spring_controller.dart';
export 'src/shader/physical_shader.dart';
export 'src/surface/physical_dot_grid.dart';
export 'src/surface/physical_lens.dart';
export 'src/surface/physical_parallax_layer.dart';
export 'src/surface/physical_pegboard.dart' show PegboardGrid, PhysicalPegboard;
export 'src/surface/physical_pressable.dart' hide PhysicalButtonBackground;
export 'src/surface/physical_surface.dart';
export 'src/text/physical_text.dart';
