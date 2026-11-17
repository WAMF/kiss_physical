import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Owns the shader instance and paint reused across repaints of one layer.
class PhysicalShaderBrush {
  /// Creates a brush that draws with [program].
  PhysicalShaderBrush(this.program);

  /// The program to draw with once it is available.
  final ValueListenable<FragmentProgram?> program;

  final _paint = Paint();
  FragmentProgram? _program;
  FragmentShader? _shader;

  /// Whether the program is loaded, creating the shader for it if so.
  ///
  /// Call this first; when it is false there is nothing to draw with yet.
  bool get isReady {
    final loaded = program.value;
    if (loaded == null) return false;
    if (!identical(loaded, _program)) {
      _shader?.dispose();
      _program = loaded;
      _shader = loaded.fragmentShader();
    }
    return true;
  }

  /// The shader to set uniforms and samplers on, once [isReady].
  FragmentShader get shader => _shader!;

  /// The paint to draw with, once every uniform and sampler of [shader] has
  /// been set. The shader is attached here and not earlier, because a paint
  /// checks that its shader's samplers are set at the moment it is given one.
  Paint get paint => _paint..shader = _shader;

  /// Releases the shader instance.
  void dispose() {
    _shader?.dispose();
    _shader = null;
  }
}
