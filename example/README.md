# kiss_physical storybook

A Widgetbook of everything in `kiss_physical`, for looking at the materials
and components on their own and changing them without running an app.

## Run it

The catalogue's index is generated and not checked in, so build it once after
checking out, from this folder:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Then on a phone or tablet, where the light follows the device:

```bash
flutter run
```

or on the desktop, or in a browser:

```bash
flutter run -d macos
```

```bash
flutter run -d chrome
```

Fragment shaders need the default (CanvasKit or Skwasm) web renderer.

## What is in it

- **Materials**: galleries of finishes, woods, stones, metals and glass,
  wear, dew, rain, fire and neon, and a playground with a knob
  for every material parameter.
- **Surfaces**: the lit body in each shape, panels and cards, glass and the
  refracting lens, the pegboard and the dot grid.
- **Light**: a light fixed over the screen, one that follows the device, and
  the sun and moon through a day.
- **Depth**: the pegboard beneath the content and a menu floating above it.
- **Controls**: pill buttons, Material buttons in the physical style, icon
  buttons, the slider and the progress bar.

The **Addons** tab has a **Light and colour** group that applies to every use
case: the accent colour, the hour of the day, where the light hangs, whether
it follows the device, and whether the use case sits on a pegboard.

## Add a use case

1. Add a function to a file under `lib/stories/`, annotated with
   `@widgetbook.UseCase(name: ..., type: ...)`.
2. Regenerate the catalogue:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Wrap content in `Stage` to centre it at a phone-like width.
