#version 460 core

// A grid of lit dots drawn in one pass. Each cell of the grid reads its
// colour and kind from one texel of a small image, so hundreds of dots cost
// a single draw: a raised bead where the texel is opaque, a recessed socket
// where it is half transparent, and nothing where it is clear. Every dot is
// a full dome shaded by the same directional light as the physical
// surfaces: Lambert diffuse, GGX specular and a Fresnel rim.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
// Unit vector pointing from the grid towards the light.
uniform vec3 uLight;
// Columns and rows of the grid.
uniform vec2 uCount;
// Gap in logical pixels between a dot and the edge of its cell.
uniform float uInset;
uniform float uPixelRatio;
// Linear colour of the directional light, and of the sky that fills shade.
uniform vec3 uKeyColor;
uniform vec3 uFillColor;
// One premultiplied texel per cell: colour, with alpha giving the kind.
uniform sampler2D uCells;

out vec4 fragColor;

const float PI = 3.14159265;
const float AMBIENT = 0.38;
const float DIELECTRIC_F0 = 0.04;
const float MAX_BEVEL_SLOPE = 0.96;
const float RIM_STRENGTH = 0.55;
const float LIGHT_TINT_REACH = 0.4;
const float DITHER = 1.0 / 255.0;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

const float NOTHING_BELOW = 0.25;
const float BEAD_FROM = 0.75;
const float BEAD_RELIEF = 1.0;
const float BEAD_ROUGHNESS = 0.3;
// Share of a bead's light that reaches its shaded side, lower than a flat
// panel's so its dome shows more contrast.
const float BEAD_AMBIENT = 0.22;
const float BEAD_SHINE = 2.0;
// A bead's shadow on the panel: strength, softness and throw, the last two
// as shares of the bead's radius.
const float BEAD_SHADOW = 0.5;
const float BEAD_SHADOW_SOFTNESS = 0.35;
const float BEAD_SHADOW_THROW = 0.3;
const float BEAD_SPECULAR_TINT = 0.25;
const float SOCKET_RELIEF = -1.0;
// Share of light lost at the bottom of a socket, where its walls block it.
const float SOCKET_SHADE = 0.5;
const float SOCKET_ROUGHNESS = 0.6;

float interleavedGradientNoise(vec2 pixel) {
  return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

void main() {
  vec2 position = FlutterFragCoord().xy;
  vec2 cellSize = uSize / uCount;
  vec2 cell = clamp(floor(position / cellSize), vec2(0.0), uCount - 1.0);

  vec2 uv = (cell + 0.5) / uCount;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  vec4 texel = texture(uCells, uv);
  if (texel.a < NOTHING_BELOW) {
    fragColor = vec4(0.0);
    return;
  }

  float radius = max(min(cellSize.x, cellSize.y) * 0.5 - uInset, 0.001);
  vec2 p = position - (cell + 0.5) * cellSize;
  float reach = length(p);
  float coverage = clamp(0.5 - (reach - radius) * uPixelRatio, 0.0, 1.0);
  float isBead = step(BEAD_FROM, texel.a);

  vec2 shadowCentre =
      -uLight.xy / max(uLight.z, 0.3) * radius * BEAD_SHADOW_THROW;
  float shadowEdge = radius * BEAD_SHADOW_SOFTNESS;
  float shadow = isBead * BEAD_SHADOW *
      (1.0 - smoothstep(-shadowEdge, shadowEdge,
                        length(p - shadowCentre) - radius));
  if (coverage <= 0.0) {
    fragColor = vec4(0.0, 0.0, 0.0, shadow);
    return;
  }

  float relief = mix(SOCKET_RELIEF, BEAD_RELIEF, isBead);
  float roughness = mix(SOCKET_ROUGHNESS, BEAD_ROUGHNESS, isBead);
  float specularTint = BEAD_SPECULAR_TINT * isBead;
  vec3 color = texel.rgb / texel.a;

  float shoulder = clamp(reach / radius, 0.0, 1.0);
  float slope = min(shoulder * shoulder, MAX_BEVEL_SLOPE);
  vec2 outward = reach > 0.0001 ? p / reach : vec2(0.0);
  vec3 normal = normalize(
      vec3(outward * slope * relief, sqrt(max(1.0 - slope * slope, 0.0))));

  vec3 light = uLight;
  vec3 halfway = normalize(light + vec3(0.0, 0.0, 1.0));
  float nDotL = max(dot(normal, light), 0.0);
  float nDotH = max(dot(normal, halfway), 0.0);
  float lDotH = max(dot(light, halfway), 0.0);
  float nDotV = max(normal.z, 0.0);

  float ambient = mix(AMBIENT, BEAD_AMBIENT, isBead);
  vec3 fill = uFillColor * ambient;
  vec3 key = uKeyColor * (1.0 - ambient);
  vec3 flatLight = fill + key;
  vec3 reference = mix(flatLight, vec3(dot(flatLight, LUMA)), LIGHT_TINT_REACH);
  vec3 diffuse = (fill + key * nDotL / light.z) / reference;

  float alpha = roughness * roughness;
  float alpha2 = alpha * alpha;
  float denominator = nDotH * nDotH * (alpha2 - 1.0) + 1.0;
  float distribution = alpha2 / (PI * denominator * denominator);
  float specular = distribution * nDotL /
      (4.0 * max(lDotH * lDotH, 0.1) * (roughness + 0.5));

  float grazing = 1.0 - nDotV;
  float grazing2 = grazing * grazing;
  float fresnel = grazing2 * grazing2 * grazing;
  vec3 reflection = vec3(2.0 * normal.z * normal.xy,
                         2.0 * normal.z * normal.z - 1.0);
  float environment = 0.5 + 0.5 * dot(reflection, light);
  float rim = fresnel * environment * environment *
      (1.0 - roughness) * RIM_STRENGTH;

  float depthShade =
      1.0 - SOCKET_SHADE * (1.0 - isBead) * (1.0 - shoulder * shoulder);
  vec3 albedo = color * color * depthShade;
  vec3 f0 = mix(vec3(DIELECTRIC_F0), albedo, specularTint);
  float shine = mix(1.0, BEAD_SHINE, isBead);
  vec3 glare = (f0 * specular + vec3(rim)) * shine * uKeyColor;
  float dither =
      (interleavedGradientNoise(position * uPixelRatio) - 0.5) * DITHER;
  vec3 lit = sqrt(albedo * diffuse + glare / (1.0 + glare)) + dither;

  fragColor = vec4(lit, 1.0) * coverage +
      vec4(0.0, 0.0, 0.0, shadow) * (1.0 - coverage);
}
