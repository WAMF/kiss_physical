import 'package:flutter_test/flutter_test.dart';

import 'shader_source.dart';

class _Metal {
  /// Metal gives each uniform of a runtime effect a buffer of its own and
  /// numbers them from 0 to 30. One over, and the shader fails to build on
  /// iOS and macOS only, at run time, leaving every surface blank.
  static const mostUniforms = 31;
}

void main() {
  test('each shader stays within the uniforms Metal allows', () {
    final uniform = RegExp(r'^uniform (?!sampler)\w+ \w+;', multiLine: true);
    final programs = ShaderSource.programs;

    expect(programs, isNotEmpty);
    for (final MapEntry(key: name, value: source) in programs.entries) {
      expect(
        uniform.allMatches(source).length,
        lessThanOrEqualTo(_Metal.mostUniforms),
        reason: name,
      );
    }
  });

  test('a program for one substance leaves the others out', () {
    final wood = ShaderSource.resolved('shaders/physical_wood.frag');
    final metal = ShaderSource.resolved('shaders/physical_metal.frag');

    expect(wood, isNot(contains('metalTexture')));
    expect(metal, contains('metalTexture'));
  });
}
