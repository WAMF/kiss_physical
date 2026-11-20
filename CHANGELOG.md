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
- **Components:** `PhysicalCard`, `PhysicalPanel`, `PhysicalPillButton`,
  `PhysicalIconButton`, `PhysicalSlider` and `PhysicalProgressBar`, with
  keyboard focus, screen-reader labels and disabled states.
- **Shaders:** one program per substance, compiled on first use;
  `PhysicalShader.precacheFor` warms the ones an app shows first and
  `PhysicalShader.hasFailed` reports a device that cannot compile them.
- **Accessibility:** reduced motion rests the light and holds flames, rain
  and flicker still.
