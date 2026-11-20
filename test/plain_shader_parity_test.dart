import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'shader_source.dart';

class _Shaders {
  static const full = 'shaders/physical_surface.frag';
  static const plain = 'shaders/physical_plain.frag';
  static final constant = RegExp(
    r'^const (\w+) (\w+) = ([^;]+);',
    multiLine: true,
  );
  static final uniform = RegExp(r'^uniform (\w+ \w+);', multiLine: true);
  static final roundedBox = RegExp(
    r'^vec3 roundedBox\(.*?^}',
    multiLine: true,
    dotAll: true,
  );

  static Map<String, String> constantsOf(String source) {
    return {
      for (final match in constant.allMatches(source))
        match.group(2)!: '${match.group(1)} ${match.group(3)}',
    };
  }

  static List<String> uniformsOf(String source) {
    return [for (final match in uniform.allMatches(source)) match.group(1)!];
  }
}

void main() {
  final full = ShaderSource.resolved(_Shaders.full);
  final plain = File(_Shaders.plain).readAsStringSync();

  test('the plain shader lights with the constants of the full one', () {
    final shared = _Shaders.constantsOf(full);
    final lean = _Shaders.constantsOf(plain);

    expect(lean, isNotEmpty);
    for (final MapEntry(key: name, value: definition) in lean.entries) {
      expect(shared[name], definition, reason: name);
    }
  });

  test('the plain shader takes the first uniforms of the full one', () {
    final lean = _Shaders.uniformsOf(plain);

    expect(lean, isNotEmpty);
    expect(_Shaders.uniformsOf(full).take(lean.length), lean);
  });

  test('both shaders outline a body with the same rounded box', () {
    final outline = _Shaders.roundedBox.firstMatch(plain)?.group(0);

    expect(outline, isNotNull);
    expect(_Shaders.roundedBox.firstMatch(full)?.group(0), outline);
  });
}
