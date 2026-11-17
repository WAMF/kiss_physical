import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Loads and shares the fragment programs behind every physical body.
abstract final class PhysicalShader {
  static final _surface =
      _Program('packages/kiss_physical/shaders/physical_surface.frag');
  static final _pegboard =
      _Program('packages/kiss_physical/shaders/physical_pegboard.frag');

  static final _dotGrid =
      _Program('packages/kiss_physical/shaders/physical_dot_grid.frag');

  static final _lens =
      _Program('packages/kiss_physical/shaders/physical_lens.frag');

  static final _plain =
      _Program('packages/kiss_physical/shaders/physical_plain.frag');

  static Future<void>? _loading;

  /// Notifies when the surface program becomes available.
  static ValueListenable<FragmentProgram?> get program => _surface.program;

  /// Notifies when the program for bodies with no texture, growth, water,
  /// vessel or effect becomes available. It lights them exactly as
  /// [program] does, at a fraction of the cost.
  static ValueListenable<FragmentProgram?> get plain => _plain.program;

  /// Notifies when the pegboard program becomes available.
  static ValueListenable<FragmentProgram?> get pegboard => _pegboard.program;

  /// Notifies when the dot grid program becomes available.
  static ValueListenable<FragmentProgram?> get dotGrid => _dotGrid.program;

  /// Notifies when the lens program becomes available.
  static ValueListenable<FragmentProgram?> get lens => _lens.program;

  /// Compiles the programs once. Until this completes, or for a program that
  /// fails, bodies paint as flat shapes in their base colour.
  static Future<void> precache() => _loading ??= Future.wait([
        _surface.load(),
        _pegboard.load(),
        _dotGrid.load(),
        _lens.load(),
        _plain.load(),
      ]);
}

class _Program {
  _Program(this.asset);

  final String asset;
  final program = ValueNotifier<FragmentProgram?>(null);

  Future<void> load() async {
    try {
      program.value = await FragmentProgram.fromAsset(asset);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'kiss_physical',
          context: ErrorDescription('while loading $asset'),
        ),
      );
    }
  }
}
