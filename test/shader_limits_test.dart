import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _Metal {
  /// Metal gives each uniform of a runtime effect a buffer of its own and
  /// numbers them from 0 to 30. One over, and the shader fails to build on
  /// iOS and macOS only, at run time, leaving every surface blank.
  static const mostUniforms = 31;
}

void main() {
  test('each shader stays within the uniforms Metal allows', () {
    final shaders = Directory('shaders')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.frag'));
    final uniform = RegExp(r'^uniform (?!sampler)\w+ \w+;', multiLine: true);

    expect(shaders, isNotEmpty);
    for (final shader in shaders) {
      final count = uniform.allMatches(shader.readAsStringSync()).length;

      expect(
        count,
        lessThanOrEqualTo(_Metal.mostUniforms),
        reason: shader.path,
      );
    }
  });
}
