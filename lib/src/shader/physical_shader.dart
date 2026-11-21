import 'package:flutter/foundation.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/shader/shader_programs.dart';

/// Compiles the fragment programs behind physical bodies ahead of time.
///
/// A program is compiled the first time a body needs it, and until it is
/// ready that body paints as a flat shape in its base colour. Compiling
/// ahead of the first frame avoids that moment.
abstract final class PhysicalShader {
  /// Whether any program has failed to compile on this device. The bodies
  /// it would have drawn paint flat in their base colour, so an app may
  /// want to fall back to a plainer look. The failure itself is reported
  /// through `FlutterError.onError`.
  static ValueListenable<bool> get hasFailed => ShaderPrograms.failed;

  /// Compiles the programs nearly every app uses: plain lit bodies, the
  /// pegboard, the dot grid and the lens.
  static Future<void> precache() {
    return Future.wait([
      ShaderPrograms.surface(SurfaceProgram.plain).load(),
      ShaderPrograms.pegboard.load(),
      ShaderPrograms.dotGrid.load(),
      ShaderPrograms.lens.load(),
    ]);
  }

  /// Compiles what [precache] does and the programs that draw [materials],
  /// for an app that knows which textures and effects it shows first.
  static Future<void> precacheFor(Iterable<PhysicalMaterial> materials) {
    return Future.wait([
      precache(),
      for (final kind in materials.map(SurfaceProgram.of).toSet())
        ShaderPrograms.surface(kind).load(),
    ]);
  }

  /// Compiles every program. Suited to tests and galleries that show every
  /// material; an app is quicker to start with [precacheFor].
  static Future<void> precacheAll() {
    return Future.wait([
      for (final program in ShaderPrograms.all) program.load(),
    ]);
  }
}
