#version 460 core

// A body with no texture that glows, burns, is rained on or is made of glass.
// The surface program with everything that belongs to other substances,
// and everything that grows, left out. See include/surface.glsl.

#define SUBSTANCE_NONE
#include "include/surface.glsl"
