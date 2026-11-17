#version 460 core

// A slab of clear glass laid over a picture of whatever is beneath it. The
// face is flat and shows the picture as it is. Towards the edge the glass
// rolls over, and there it bends the view: each point looks at the picture
// further in towards the middle, more steeply the closer to the edge, so
// the rim holds a squeezed copy of what lies inside it. Red, green and blue
// bend by slightly different amounts, which fringes the rim with colour.
// The same directional light as the physical surfaces puts a highlight on
// the lit side of the rim and a soft shade on the other.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
// Corner radii: top-left, top-right, bottom-right, bottom-left.
uniform vec4 uRadii;
// Unit vector pointing from the glass towards the light.
uniform vec3 uLight;
// How far the rim bends the view, as a share of its own width; the width
// of the rim in pixels; how far the colours part, from 0 to 1; and how
// strongly the tint shows, from 0 to 1.
uniform vec4 uLens;
// sRGB colour of the glass.
uniform vec3 uTint;
// Linear colour of the directional light.
uniform vec3 uKeyColor;
uniform float uPixelRatio;
// What lies beneath the glass, premultiplied.
uniform sampler2D uBackdrop;

out vec4 fragColor;

const float SHININESS = 90.0;
const float RIM_LIGHT = 0.55;
const float RIM_SHADE = 0.3;
const float EDGE_LINE = 0.35;

// Returns (distance, outward gradient) of the rounded box centred on origin.
vec3 roundedBox(vec2 p, vec2 halfSize) {
  float radius = p.x < 0.0
      ? (p.y < 0.0 ? uRadii.x : uRadii.w)
      : (p.y < 0.0 ? uRadii.y : uRadii.z);
  vec2 q = abs(p) - halfSize + radius;
  vec2 corner = max(q, 0.0);
  float outside = length(corner);
  float dist = outside + min(max(q.x, q.y), 0.0) - radius;
  vec2 gradient = outside > 0.0001
      ? corner / outside
      : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
  return vec3(dist, gradient * sign(p));
}

vec4 backdropAt(vec2 position) {
  vec2 uv = clamp(position / uSize, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uBackdrop, uv);
}

void main() {
  vec2 position = FlutterFragCoord().xy;
  vec2 halfSize = uSize * 0.5;
  vec2 p = position - halfSize;
  vec3 box = roundedBox(p, halfSize);
  float coverage = clamp(0.5 - box.x * uPixelRatio, 0.0, 1.0);

  float rimWidth = max(uLens.y, 0.001);
  float shoulder = 1.0 - clamp(-box.x / rimWidth, 0.0, 1.0);
  float slope = shoulder * shoulder;
  vec2 bend = box.yz * slope * uLens.x * rimWidth;
  float parting = uLens.z * 0.35;

  vec4 green = backdropAt(position - bend);
  vec4 seen = vec4(backdropAt(position - bend * (1.0 + parting)).r, green.g,
                   backdropAt(position - bend * (1.0 - parting)).b, green.a);

  float body = uLens.w * (0.35 + 0.65 * slope);
  seen.rgb = mix(seen.rgb, uTint * seen.a, body);

  vec3 normal = normalize(vec3(box.yz * slope, 1.0 - 0.6 * slope));
  vec3 halfway = normalize(uLight + vec3(0.0, 0.0, 1.0));
  float glint = pow(max(dot(normal, halfway), 0.0), SHININESS);
  float facing = dot(box.yz, uLight.xy);
  float lit = slope * max(facing, 0.0) * RIM_LIGHT;
  float shaded = slope * max(-facing, 0.0) * RIM_SHADE;
  float line = EDGE_LINE * smoothstep(1.5, 0.0, -box.x) * (0.4 + 0.6 * abs(facing));

  vec3 glare = uKeyColor * (glint * slope + lit + line);
  vec4 glass = vec4(seen.rgb * (1.0 - shaded) + glare,
                    max(seen.a, min(dot(glare, vec3(0.333)) + shaded, 1.0)));
  fragColor = mix(backdropAt(position), glass, coverage);
}
