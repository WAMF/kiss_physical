#version 460 core

// Lit pegboard. A flat panel is covered by a regular grid of round sockets,
// each one a fully domed recess shaded by the same single directional light
// as the physical surfaces: Lambert diffuse, GGX specular and a Fresnel rim.
// A soft wash brightens the panel on the side the light leans towards. The
// grid is folded into one cell, so the whole board costs one analytic pass:
// no textures, no derivatives, no loops. Moving the grid origin slides the
// sockets, as when content scrolls; the wash is lighting and stays put.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
// Straight-alpha sRGB panel colour.
uniform vec4 uColor;
// Unit vector pointing from the panel towards the light.
uniform vec3 uLight;
// socket pitch, socket radius, grid origin x, grid origin y.
uniform vec4 uGrid;
// roughness, specular tint, relief (-1 inset .. 1 raised), wash strength.
uniform vec4 uSurface;
uniform float uPixelRatio;

out vec4 fragColor;

const float PI = 3.14159265;
const float AMBIENT = 0.38;
const float DIELECTRIC_F0 = 0.04;
const float MAX_BEVEL_SLOPE = 0.96;
const float RIM_STRENGTH = 0.55;
const float WASH_LEAN = 0.7;
const float DITHER = 1.0 / 255.0;

float interleavedGradientNoise(vec2 pixel) {
  return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

void main() {
  vec2 position = FlutterFragCoord().xy;

  float pitch = uGrid.x;
  float radius = max(uGrid.y, 0.001);
  vec2 origin = uGrid.zw;
  float pixelRatio = uPixelRatio;
  float roughness = uSurface.x;
  float specularTint = uSurface.y;
  float relief = uSurface.z;
  float washStrength = uSurface.w;

  float washReach = max(uSize.x, uSize.y);
  vec2 washCentre = uSize * 0.5 + uLight.xy * washReach * WASH_LEAN;
  float wash = washStrength *
      clamp(1.0 - distance(position, washCentre) / washReach, 0.0, 1.0);
  vec3 panel = mix(uColor.rgb, vec3(1.0), wash);

  float dither =
      (interleavedGradientNoise(position * pixelRatio) - 0.5) * DITHER;

  vec2 p = mod(position - origin, pitch) - 0.5 * pitch;
  float reach = length(p);
  float coverage = clamp(0.5 - (reach - radius) * pixelRatio, 0.0, 1.0);

  if (coverage <= 0.0) {
    fragColor = vec4(panel + dither, 1.0) * uColor.a;
    return;
  }

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

  float diffuse = AMBIENT + (1.0 - AMBIENT) * nDotL / light.z;

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

  vec3 albedo = uColor.rgb * uColor.rgb;
  vec3 f0 = mix(vec3(DIELECTRIC_F0), albedo, specularTint);
  vec3 glare = f0 * specular + vec3(rim);
  vec3 socket = sqrt(albedo * diffuse + glare / (1.0 + glare));

  fragColor = vec4(mix(panel, socket, coverage) + dither, 1.0) * uColor.a;
}
