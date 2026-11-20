#version 460 core

// Lit rounded-box surface. A signed distance field describes the outline, a
// rounded shoulder plus a gentle crown describe the height, and a single
// directional light shades it with Lambert diffuse, GGX specular and a
// Fresnel rim. The light and the sky each have a colour: sides turned to
// the light take its colour, sides turned away take the sky's, and flat
// faces stay exactly the base colour. The shoulder's lean falls off
// quadratically, so it meets the face with no crease for a highlight to stop
// against.
//
// Three optional layers build on that body, each drawn from noise with no
// images. A texture makes it wood, metal, plastic, stone or marble. Wear
// ages it and marks it with flaws, and reports where its hollows are.
// Decals then grow or settle on top, reading those hollows: moss, grass and
// flowers start in cracks and pits, and water beads, pools and runs.
//
// The layers talk through a hint map, worked out for each point as the
// layers are applied in order. Every layer adds what it knows and any later
// layer may read it:
//   x  hollow    how deep inside a groove, pit, chip or crack the point is
//   y  shelter   how close it is to a hollow or an edge, where things lodge
//   z  porosity  how readily the finish soaks water up
//   w  cover     how much of it is hidden under something grown on top
// A hint is only known at the point being drawn, so a layer that others
// need to find from a distance writes a widened copy of itself as shelter.
//
// This is the whole of it: any substance, with growth. A body with nothing
// grown on it is drawn by the leaner program for its substance.

#define GROWTH
#include "include/surface.glsl"
