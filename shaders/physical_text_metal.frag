#version 460 core

// Lettering of metal.
// The surface program with strokes for an outline in place of a rounded
// box, and everything that belongs to other substances left out. See
// include/surface.glsl.

#define SUBSTANCE_METAL
#define OUTLINE_GLYPHS
#include "include/surface.glsl"
