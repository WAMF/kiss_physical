import 'package:flutter/widgets.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:widgetbook/widgetbook.dart';

/// A knob for what the bodies in a use case are made of, so the same shapes
/// and finishes can be compared from one substance to the next.
abstract final class SubstanceKnob {
  static const _label = 'Made of';
  static const _madeOf = 'made of';

  static const _substances = {
    'plain': PhysicalTexture.none,
    'oak': PhysicalTexture.oak,
    'walnut': PhysicalTexture.walnut,
    'stainless steel': PhysicalTexture.stainlessSteel,
    'brass': PhysicalTexture.brass,
    'granite': PhysicalTexture.granite,
    'carrara': PhysicalTexture.carrara,
    'plastic': PhysicalTexture.plastic,
  };

  /// The substance chosen in the knobs of the use case being built in
  /// [context], plain to begin with. [part] names the part it is for when
  /// a use case has a knob for each of several.
  static PhysicalTexture of(BuildContext context, {String? part}) {
    return context.knobs.object.dropdown<PhysicalTexture>(
      label: part == null ? _label : '$part $_madeOf',
      options: _substances.values.toList(),
      labelBuilder: _nameOf,
    );
  }

  static String _nameOf(PhysicalTexture texture) {
    return _substances.entries
        .firstWhere((entry) => entry.value == texture)
        .key;
  }
}
