#version 460 core

// The plain body of include/surface.glsl on its own: the same rounded box,
// shoulder, crown, light and cast shadow, with no texture, wear, water,
// vessel or effect. Most bodies in an app are plain, and this draws
// them without carrying the cost of the layers they do not have. The two
// must light a plain body identically, so any change to the outline or the
// lighting belongs in both.
//
// The uniforms are the first nine of include/surface.glsl, in its order.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
// Corner radii: top-left, top-right, bottom-right, bottom-left.
uniform vec4 uRadii;
// Straight-alpha sRGB base colour.
uniform vec4 uColor;
// Unit vector pointing from the surface towards the light.
uniform vec3 uLight;
// roughness, specular tint, bevel width, crown.
uniform vec4 uSurface;
// relief (-1 inset .. 1 raised), elevation, device pixel ratio, overlay flag.
uniform vec4 uForm;
// N.L of a flat face under the current light.
uniform float uFlatIncidence;
// Linear colour of the directional light.
uniform vec3 uKeyColor;
// Linear colour of the sky light reaching sides turned away from the key.
uniform vec3 uFillColor;

out vec4 fragColor;

const float PI = 3.14159265;
const float AMBIENT = 0.38;
const float DIELECTRIC_F0 = 0.04;
const float MAX_BEVEL_SLOPE = 0.96;
const float RIM_STRENGTH = 0.55;
const float SHADOW_STRENGTH = 0.45;
const float OVERLAY_SHADE = 0.55;
const float OVERLAY_BACKDROP = 0.05;
const float OVERLAY_LIFT = 2.5;
const float DITHER = 1.0 / 255.0;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float LIGHT_TINT_REACH = 0.4;
const float MEDIAL_BLEND = 2.0;

// Signed distance to the rounded box in x and the outward direction in yz.
// Deep inside, the two nearest edges are blended into each other so their
// meeting does not show as a crease.
vec3 roundedBox(vec2 p, vec2 halfSize) {
  float radius = p.x < 0.0
      ? (p.y < 0.0 ? uRadii.x : uRadii.w)
      : (p.y < 0.0 ? uRadii.y : uRadii.z);
  vec2 q = abs(p) - halfSize + radius;
  vec2 corner = max(q, 0.0);
  float outside = length(corner);
  if (outside > 0.0001) {
    return vec3(outside + min(max(q.x, q.y), 0.0) - radius,
                corner / outside * sign(p));
  }
  vec2 depth = -q;
  float wedge = MEDIAL_BLEND * depth.x * depth.y /
      max(depth.x + depth.y, 0.0001);
  float nearSide =
      clamp(0.5 + 0.5 * (depth.y - depth.x) / max(wedge, 0.0001), 0.0, 1.0);
  float nearest = mix(depth.y, depth.x, nearSide) -
      wedge * nearSide * (1.0 - nearSide);
  vec2 gradient = normalize(vec2(nearSide, 1.0 - nearSide));
  return vec3(-nearest - radius, gradient * sign(p));
}

float interleavedGradientNoise(vec2 pixel) {
  return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

void main() {
  vec2 halfSize = uSize * 0.5;
  vec2 coord = FlutterFragCoord().xy;
  vec2 p = coord - halfSize;

  float roughness = uSurface.x;
  float specularTint = uSurface.y;
  float bevel = max(uSurface.z, 0.001);
  float crown = uSurface.w;
  float relief = uForm.x;
  float elevation = uForm.y;
  float pixelRatio = uForm.z;
  float overlay = uForm.w;

  vec3 box = roundedBox(p, halfSize);
  float coverage = clamp(0.5 - box.x * pixelRatio, 0.0, 1.0);
  vec3 light = uLight;

  float shadow = 0.0;
  if (overlay < 0.5 && coverage * uColor.a < 1.0 && elevation >= 0.001) {
    vec2 shadowOffset = -light.xy / max(light.z, 0.3) * elevation;
    float softness = elevation * 1.2 + 1.0;
    float shadowDistance = roundedBox(p - shadowOffset, halfSize).x;
    shadow = SHADOW_STRENGTH * uColor.a *
        (1.0 - smoothstep(-softness, softness, shadowDistance));
  }
  if (coverage <= 0.0) {
    fragColor = vec4(0.0, 0.0, 0.0, shadow);
    return;
  }

  float shoulder = 1.0 - clamp(-box.x / bevel, 0.0, 1.0);
  float slope = min(shoulder * shoulder, MAX_BEVEL_SLOPE);
  vec2 lean = box.yz * slope * relief + (p / halfSize) * crown * sign(relief);
  vec3 normal = normalize(vec3(lean, sqrt(max(1.0 - slope * slope, 0.0))));

  vec3 halfway = normalize(light + vec3(0.0, 0.0, 1.0));
  float nDotL = max(dot(normal, light), 0.0);
  float nDotH = max(dot(normal, halfway), 0.0);
  float lDotH = max(dot(light, halfway), 0.0);
  float nDotV = max(normal.z, 0.0);

  vec3 fill = uFillColor * AMBIENT;
  vec3 key = uKeyColor * (1.0 - AMBIENT);
  vec3 flatLight = fill + key;
  vec3 reference = mix(flatLight, vec3(dot(flatLight, LUMA)), LIGHT_TINT_REACH);
  vec3 diffuse = (fill + key * (nDotL / uFlatIncidence)) / reference;

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
  vec3 glare = (f0 * specular + vec3(rim)) * uKeyColor;
  vec3 highlights = glare / (1.0 + glare);

  float dither =
      (interleavedGradientNoise(coord * pixelRatio) - 0.5) * DITHER;

  if (overlay > 0.5) {
    float brightness = dot(diffuse, LUMA);
    float shade = clamp((1.0 - brightness) * OVERLAY_SHADE, 0.0, 1.0);
    float lift = clamp((brightness - 1.0) * OVERLAY_LIFT, 0.0, 1.0);
    vec3 glint = sqrt(OVERLAY_BACKDROP + highlights) - sqrt(OVERLAY_BACKDROP);
    fragColor = vec4(glint + vec3(lift) + dither, shade + lift) * coverage;
    return;
  }

  vec3 lit = sqrt(albedo * diffuse + highlights) + dither;
  vec4 surface = vec4(lit, 1.0) * uColor.a * coverage;
  fragColor = surface + vec4(0.0, 0.0, 0.0, shadow) * (1.0 - surface.a);
}
