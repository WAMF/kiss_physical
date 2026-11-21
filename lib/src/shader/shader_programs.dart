import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/material/physical_texture.dart';

/// The programs a body can be drawn with. Each leaves out what a body of
/// its kind never needs, so it is quicker to compile and to run.
enum SurfaceProgram {
  /// A lit shape with no texture, water, vessel or effect.
  plain('physical_plain'),

  /// A body with no texture that glows, burns, is rained on or is glass.
  effects('physical_effects'),

  /// A body of wood.
  wood('physical_wood'),

  /// A body of metal.
  metal('physical_metal'),

  /// A body of moulded plastic.
  plastic('physical_plastic'),

  /// A body of stone.
  stone('physical_stone'),

  /// A body of marble.
  marble('physical_marble');

  const SurfaceProgram(this._name);

  final String _name;

  /// The program that draws a body of [material].
  static SurfaceProgram of(PhysicalMaterial material) {
    final decals = material.decals;
    final texture = material.texture;
    if (!texture.isPlain) return _bySubstance[texture.substance]!;
    final isBare =
        decals.isEmpty && material.vessel == null && material.effects.isEmpty;
    return isBare ? plain : effects;
  }

  static const _bySubstance = {
    PhysicalSubstance.plain: effects,
    PhysicalSubstance.wood: wood,
    PhysicalSubstance.metal: metal,
    PhysicalSubstance.plastic: plastic,
    PhysicalSubstance.stone: stone,
    PhysicalSubstance.marble: marble,
  };
}

/// Loads and shares the fragment programs behind every physical body.
///
/// A program is compiled the first time something asks for it. Until then,
/// and if it fails, bodies paint as flat shapes in their base colour.
abstract final class ShaderPrograms {
  static final _surfaces = {
    for (final program in SurfaceProgram.values)
      program: ShaderProgram(program._name),
  };

  /// The program behind `PhysicalPegboard`.
  static final pegboard = ShaderProgram('physical_pegboard');

  /// The program behind `PhysicalDotGrid`.
  static final dotGrid = ShaderProgram('physical_dot_grid');

  /// The program behind `PhysicalLens`.
  static final lens = ShaderProgram('physical_lens');

  static final _lettering = {
    for (final program in SurfaceProgram.values)
      program: ShaderProgram(
        program._name.replaceFirst(_bodyPrefix, _letteringPrefix),
      ),
  };

  static const _bodyPrefix = 'physical_';
  static const _letteringPrefix = 'physical_text_';

  /// Whether any program has failed to compile, which leaves the bodies
  /// it draws flat.
  static final failed = ValueNotifier<bool>(false);

  /// The program that draws bodies of [kind].
  static ShaderProgram surface(SurfaceProgram kind) => _surfaces[kind]!;

  /// The program that draws the lettering of `PhysicalText` as a body of
  /// [kind] would be drawn.
  static ShaderProgram lettering(SurfaceProgram kind) => _lettering[kind]!;

  /// Every program there is.
  static Iterable<ShaderProgram> get all =>
      [..._surfaces.values, ..._lettering.values, pegboard, dotGrid, lens];
}

/// One fragment program, compiled when it is first wanted.
class ShaderProgram {
  /// Creates the program kept in the shader file called [name].
  ShaderProgram(String name) : _asset = '$_folder$name.frag';

  static const _folder = 'shaders/';

  /// Where the package's assets are found when it is used by an app.
  static const _packagePrefix = 'packages/kiss_physical/';

  final String _asset;
  final _program = ValueNotifier<FragmentProgram?>(null);
  Future<void>? _loading;
  Zone? _loadingZone;
  int _attempt = 0;

  /// Notifies when the program becomes available, and starts compiling it
  /// if nothing has yet.
  ValueListenable<FragmentProgram?> get whenLoaded {
    unawaited(load());
    return _program;
  }

  /// Whether programs may be compiled. A test turns this off to see how a
  /// body paints while its program has yet to arrive.
  @visibleForTesting
  static bool isLoadingAllowed = true;

  /// Compiles the program once.
  ///
  /// A compile begun in another zone is not waited on: a widget test's fake
  /// clock can leave one that never finishes, and waiting on it would hang
  /// whatever asked next.
  Future<void> load() {
    if (!isLoadingAllowed || _program.value != null) return Future.value();
    final pending = _loading;
    if (pending != null && identical(_loadingZone, Zone.current)) {
      return pending;
    }
    _loadingZone = Zone.current;
    return _loading = _load(_attempt);
  }

  /// Forgets the program, as if nothing had asked for it yet.
  @visibleForTesting
  void unload() {
    _attempt++;
    _loading = null;
    _program.value = null;
  }

  Future<void> _load(int attempt) async {
    try {
      final loaded = await _fromEither();
      if (attempt == _attempt) _program.value = loaded;
    } on Object catch (error, stackTrace) {
      if (attempt == _attempt) ShaderPrograms.failed.value = true;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'kiss_physical',
          context: ErrorDescription('while loading $_asset'),
        ),
      );
    }
  }

  /// Loads the program as an app sees it, or failing that as the package
  /// sees its own assets, which is how its tests find them.
  Future<FragmentProgram> _fromEither() async {
    try {
      return await FragmentProgram.fromAsset('$_packagePrefix$_asset');
    } on Object {
      return FragmentProgram.fromAsset(_asset);
    }
  }
}
