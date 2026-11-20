# Contributing to kiss_physical

## Set up

```bash
flutter pub get
flutter test
```

The storybook is in `example/`. Its index is generated:

```bash
cd example
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Before opening a pull request

```bash
dart format lib test
flutter analyze
flutter test
```

Analysis must be clean, including a doc comment on every public member.

## Changing how anything looks

The shaders are the product, so their output is tested as pictures. The
reference sheets are in `test/golden/images` and are recorded on macOS; CI
checks them on macOS only, because other platforms round the noise behind
textures differently.

If a change is meant to alter the look, record the sheets again and review
the difference before committing it:

```bash
flutter test --update-goldens test/golden
```

If a change is not meant to alter the look, the sheets must still pass
untouched.

## Shaders

- `shaders/include/surface.glsl` is the source of every surface program.
  Each `.frag` beside it sets switches and includes it: one per substance,
  one for effects on a bare body, and `physical_surface.frag` with growth.
- Metal allows a program 31 uniforms. `test/shader_limits_test.dart` counts
  them for every program. Put values that belong together in one uniform.
- Uniforms are set by position from Dart, so a new one goes at the end of
  its group and its index is added in `physical_surface.dart`. Uniforms that
  only some programs take go last.
- `physical_plain.frag` must light a body exactly as the full program does.
  `test/plain_shader_parity_test.dart` holds the two together.

## Versions

The package follows semantic versioning. Before 1.0.0, a minor version may
change the public interface and the changelog says how; a patch version
never does. The public interface is what `lib/kiss_physical.dart` exports.
Anything under `lib/src/` that it does not export may change at any time.

## Releasing

1. Set the version in `pubspec.yaml` and describe it in `CHANGELOG.md`.
2. Record the screenshots again if the look has changed
   (`tool/screenshots/make_screenshots_test.dart` says how).
3. Merge to `main`, then push a tag of the form `v0.1.0`. The publish
   workflow sends that version to pub.dev.
