import 'dart:io';

/// Reads shader sources as the compiler sees them: with the files they
/// include pasted in and the parts their switches leave out removed.
abstract final class ShaderSource {
  static const folder = 'shaders';
  static final _include = RegExp(r'^#include "(.+)"$');
  static final _define = RegExp(r'^#define (\w+)$');
  static final _ifdef = RegExp(r'^#ifdef (\w+)$');
  static final _if = RegExp(r'^#(el)?if (.+)$');
  static final _defined = RegExp(r'(!?)defined\((\w+)\)');

  /// Every program in the package, by file name.
  static Map<String, String> get programs {
    return {
      for (final file in Directory(folder).listSync().whereType<File>())
        if (file.path.endsWith('.frag'))
          file.uri.pathSegments.last: resolved(file.path),
    };
  }

  /// The source of the program at [path] after preprocessing.
  static String resolved(String path) {
    final defined = <String>{};
    final kept = <String>[];
    final taking = <bool>[];
    final taken = <bool>[];

    void read(String file) {
      for (final line in File(file).readAsLinesSync()) {
        final isLive = taking.every((take) => take);
        final ifdef = _ifdef.firstMatch(line);
        final condition = _if.firstMatch(line);
        if (ifdef != null) {
          final take = defined.contains(ifdef.group(1));
          taking.add(take);
          taken.add(take);
        } else if (condition != null && condition.group(1) == null) {
          final take = _holds(condition.group(2)!, defined);
          taking.add(take);
          taken.add(take);
        } else if (condition != null) {
          final take = !taken.last && _holds(condition.group(2)!, defined);
          taking.last = take;
          taken.last = taken.last || take;
        } else if (line == '#else') {
          taking.last = !taken.last;
        } else if (line == '#endif') {
          taking.removeLast();
          taken.removeLast();
        } else if (!isLive) {
          continue;
        } else if (_define.firstMatch(line) case final define?) {
          defined.add(define.group(1)!);
        } else if (_include.firstMatch(line) case final include?) {
          read('$folder/${include.group(1)}');
        } else {
          kept.add(line);
        }
      }
    }

    read(path);
    return kept.join('\n');
  }

  /// Whether a condition made of `defined(X)` terms joined by `||` holds.
  static bool _holds(String condition, Set<String> defined) {
    return _defined.allMatches(condition).any((term) {
      final isNegated = term.group(1) == '!';
      return defined.contains(term.group(2)) != isNegated;
    });
  }
}
