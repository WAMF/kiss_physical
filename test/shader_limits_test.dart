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

  test('programs that leave growth out leave room for more uniforms', () {
    final uniform = RegExp(r'^uniform (?!sampler)\w+ \w+;', multiLine: true);
    final wood = ShaderSource.resolved('shaders/physical_wood.frag');
    final grown = ShaderSource.resolved('shaders/physical_surface.frag');

    expect(
      uniform.allMatches(wood).length,
      lessThan(uniform.allMatches(grown).length),
    );
    expect(wood, isNot(contains('metalTexture')));
    expect(wood, isNot(contains('flowerAt')));
    expect(grown, contains('flowerAt'));
  });
}
