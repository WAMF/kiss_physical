#version 460 core

// Lit lettering. The body of physical_plain.frag with glyphs for an
// outline: the same shoulder, light and cast shadow, with no texture, wear,
// water, vessel or effect. The two must light a body identically, so any
// change to the lighting belongs in both.
//
// A rounded box knows its own distance to its edge; letters do not, so
// they arrive drawn into a map. Red holds the letters as they are, which is
// where the body is. Green holds the same letters blurred, which rises from
// nothing outside a stroke, through a half at its edge, to one deep inside:
// its height is the shoulder and its slope is which way the shoulder faces.
// A stroke too thin for the blur to reach one never flattens, and so is
// rounded right across.

#include <flutter/runtime_effect.glsl>

precision highp float;

// Size of the map, which reaches past the lettering on every side.
uniform vec2 uSize;
// Where the map's top left corner lies.
uniform vec2 uOrigin;
// Straight-alpha sRGB base colour.
uniform vec4 uColor;
// Unit vector pointing from the surface towards the light.
uniform vec3 uLight;
// roughness, specular tint, how far apart the slope is measured, relief
// (-1 inset .. 1 raised).
uniform vec4 uSurface;
// elevation, device pixel ratio.
uniform vec2 uForm;
// N.L of a flat face under the current light.
uniform float uFlatIncidence;
// Linear colour of the directional light.
uniform vec3 uKeyColor;
// Linear colour of the sky light reaching sides turned away from the key.
uniform vec3 uFillColor;
// The lettering in red and the blurred lettering in green.
uniform sampler2D uGlyphs;

out vec4 fragColor;

const float PI = 3.14159265;
const float AMBIENT = 0.38;
const float DIELECTRIC_F0 = 0.04;
const float MAX_BEVEL_SLOPE = 0.96;
const float RIM_STRENGTH = 0.55;
const float SHADOW_STRENGTH = 0.45;
const float DITHER = 1.0 / 255.0;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float LIGHT_TINT_REACH = 0.4;
// The blurred lettering's value at the edge of a stroke.
const float EDGE = 0.5;
// Keeps the facing of a shoulder steady where the slope dies away, along
// the middle of a stroke.
const float LEVEL_SLOPE = 0.04;

vec4 glyphsAt(vec2 position) {
  vec2 uv = clamp((position - uOrigin) / uSize, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uGlyphs, uv);
}

float interleavedGradientNoise(vec2 pixel) {
  return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

void main() {
  vec2 coord = FlutterFragCoord().xy;

  float roughness = uSurface.x;
  float specularTint = uSurface.y;
  float apart = uSurface.z;
  float relief = uSurface.w;
  float elevation = uForm.x;
  float pixelRatio = uForm.y;

  vec4 glyphs = glyphsAt(coord);
  float coverage = glyphs.r;
  vec3 light = uLight;

  float shadow = 0.0;
  if (coverage * uColor.a < 1.0 && elevation >= 0.001) {
    vec2 shadowOffset = -light.xy / max(light.z, 0.3) * elevation;
    shadow = SHADOW_STRENGTH * uColor.a *
        smoothstep(0.0, 1.0, glyphsAt(coord - shadowOffset).g);
  }
  if (coverage <= 0.0) {
    fragColor = vec4(0.0, 0.0, 0.0, shadow);
    return;
  }

  vec2 rise = vec2(
      glyphsAt(coord + vec2(apart, 0.0)).g -
          glyphsAt(coord - vec2(apart, 0.0)).g,
      glyphsAt(coord + vec2(0.0, apart)).g -
          glyphsAt(coord - vec2(0.0, apart)).g);
  vec2 outward = -rise / (length(rise) + LEVEL_SLOPE);

  float shoulder = 1.0 - clamp((glyphs.g - EDGE) / (1.0 - EDGE), 0.0, 1.0);
  float slope = min(shoulder * shoulder, MAX_BEVEL_SLOPE);
  vec2 lean = outward * slope * relief;
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

  vec3 lit = sqrt(albedo * diffuse + highlights) + dither;
  vec4 surface = vec4(lit, 1.0) * uColor.a * coverage;
  fragColor = surface + vec4(0.0, 0.0, 0.0, shadow) * (1.0 - surface.a);
}
