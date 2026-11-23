## 0.1.0

First release.

- **Light:** `WorldLight` follows the tilt of the device, `PointerLight`
  follows the pointer on desktop and web, and `PhysicalLight.fixed` places
  a light by hand. `SkyLight` gives the sun's and moon's lean and colour.
- **Surfaces:** `PhysicalSurface`, `PhysicalPressable`, `PhysicalGlass`,
  `PhysicalLens`, `PhysicalPegboard`, `PhysicalParallaxLayer` and
  `PhysicalDotGrid`.
- **Materials:** `PhysicalMaterial` presets, with textures (woods, marbles,
  stones, metals, plastic), wear, dew, glass, and
  rain, flame and neon effects.
- **Lettering:** `PhysicalText` makes headings and numerals of a material:
  every stroke has a lit shoulder and casts a shadow, and takes the
  textures, wear and dew a surface does.
- **Motion:** pressing is moved by springs, and how a body moves and taps
  the hand follows from what it is made of (`PhysicalFeel`): plastic
  bounces, stone settles. `PhysicalHaptics` turns the taps off.
  `PhysicalPressable` and `PhysicalIconButton` can repeat while held
  (`HoldRepeater`), and a pressable can answer a hold. `SpringController`
  and `PhysicalMotion` (throws, stops and resistance past an edge) are
  there for gestures to come.
- **Components:** `PhysicalCard`, `PhysicalPanel`, `PhysicalPillButton`,
  `PhysicalIconButton`, `PhysicalSwitch`, `PhysicalSegmentedControl`,
  `PhysicalTextField`, `PhysicalSpinner`, `PhysicalSlider` and
  `PhysicalProgressBar`, with
  keyboard focus, screen-reader labels and disabled states. Each keeps its
  own colour whatever it is made of, and the slider and progress bar take
  a material for each part.
- **Gestures:** `PhysicalSheet` is dragged or thrown down out of the way,
  `PhysicalSwipeRow` slides aside to show the actions behind it, and
  `PhysicalPager` is thrown from page to page. Each settles on a spring
  and gives a little where it cannot go.
- **Shaders:** one program per substance, compiled on first use;
  `PhysicalShader.precacheFor` warms the ones an app shows first and
  `PhysicalShader.hasFailed` reports a device that cannot compile them.
- **Accessibility:** reduced motion rests the light and holds flames, rain
  and flicker still.
