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
// N.L of a flat face under the current light. Dividing by it keeps flat
// faces at exactly the base colour wherever the light is.
uniform float uFlatIncidence;
// Linear colour of the directional light: the sun or the moon.
uniform vec3 uKeyColor;
// Linear colour of the sky light reaching sides turned away from the key.
uniform vec3 uFillColor;
// Procedural texture: kind (0 none, 1 wood, 2 metal, 3 plastic, 4 stone,
// 5 marble), scale of its features, strength from 0 to 1.
uniform vec3 uTexture;
// Four numbers shaping the texture; what each means depends on its kind.
uniform vec4 uFigure;
// sRGB colour of the grain, veins or flecks.
uniform vec3 uSecondColor;
// sRGB colour the surface stains or tarnishes towards as it ages.
uniform vec3 uPatinaColor;
// How worn the body is, each from 0 to 1: its age, how scratched and
// scuffed it is, and how dented, pitted, chipped and cracked.
uniform vec3 uWear;
// How scratches fall: the angle most of them run at in radians, how far
// others stray from it (0 to 1), and how much they gather into patches
// (0 to 1).
uniform vec3 uScratch;
// Growth on top of the surface, each from 0 to 1: moss, grass, flowers.
uniform vec3 uGrowth;
// sRGB colour of the flower petals.
uniform vec3 uBloomColor;
// Water on top of the surface: dew and rain, each from 0 to 1, and the
// time in seconds that animates the rain.
uniform vec3 uWater;
// Which way is down within the surface in xy, with a length from 0 (lying
// flat) to 1 (upright) for how strongly water runs. Then z: above 0.5,
// draws the hint map in place of the surface, with hollows in red, cover
// in green and water in blue, over shelter in grey.
//
// Metal gives every uniform a buffer of its own and allows 31, so values
// that belong together share one.
uniform vec3 uWorld;
// A special way of drawing the body: kind (0 none, 1 neon, 2 flame,
// 3 glass, 4 liquid in glass), intensity from 0 to 1, the width of a neon
// tube bent round the outline (0 fills the body), and how much neon
// flickers or how turbulent flames are, from 0 to 1.
uniform vec4 uEffect;
// sRGB colour of the glow, the fire, the glass or the liquid.
uniform vec3 uEffectColor;
// How far flames rise in pixels, how solid glass is, how full a vessel is
// and how dark its liquid gets through its depth, each of the last three
// from 0 to 1.
uniform vec4 uEffectShape;
// Unit vector pointing down, for flames.
uniform vec2 uEffectDown;
// The surface of the liquid: the unit direction it faces, how disturbed
// it is and how much of a head of foam stands on it, each from 0 to 1. The
// surface is a flat plane swung by a spring outside the shader; nothing is
// simulated here.
uniform vec4 uLiquid;
// How the drawing is split up. x: above 0.5 when uRainMap holds the rain
// on this surface. y: which part of the work to do. 0 draws the whole body
// in one go. 1 bakes everything about it that does not move or depend on
// the light, its texture, wear and growth, into uBaked. 2 reads that back
// and only does what changes from frame to frame: the light, water and
// effects. zw: the size of uBaked in the surface's logical pixels.
uniform vec4 uStage;
// What a flame effect does to the body: how readily it burns, from 0 (bare
// metal, which only darkens a little) to 1 (wood, which chars and glows),
// how far in from the edge the char reaches in pixels, and how much of the
// char glows with embers, from 0 to 1.
uniform vec3 uScorch;
// How far flames have streamed since the fire was lit, in seconds of
// travel along the way they fall away from. It is added up outside the
// shader so that turning the fire bends its flames without hurrying them.
uniform vec2 uEffectFlow;
// What the body is made of in place of its own colour and texture: kind
// (0 solid, 1 glass, 2 glass holding liquid) and the sRGB tint of the
// glass or colour of the liquid.
uniform vec4 uVessel;
// How far the bubbles in a liquid have risen, as seconds of travel down
// the way they rise against. It is added up outside the shader so that
// sloshing the liquid turns their path without flinging them about.
uniform vec2 uLiquidFlow;
// The rain, one texel to a pixel of the surface: the height of each drop
// in red and how wet the trails have left the surface in green. The drops
// are moved outside the shader, where each can keep a motion of its own.
uniform sampler2D uRainMap;
// The baked body, four tiles each the size of the surface. Top left, its
// colour. Top right, how its fine relief leans away from its plain shape
// in red and green, and its roughness in blue. Bottom left, its specular
// tint, half its diffuse share and its cover hint. Bottom right, its hollow
// and porosity hints and how much moss is on it.
uniform sampler2D uBaked;

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
// Share of its colour a brushed metal still scatters; the rest it reflects.
const float METAL_DIFFUSE = 0.55;
// How far a fully aged surface moves to its patina colour, and how much
// rougher it gets.
const float AGE_STAIN = 0.85;
// Share of its brightness an oxidised metal keeps.
const float METAL_OXIDE = 0.45;
const float AGE_SOFT_STAIN = 0.45;
const float AGE_MELLOWING = 0.3;
const float AGE_ROUGHNESS = 0.22;

const vec3 FLAME_WHITE = vec3(1.0, 0.95, 0.75);
const vec3 FLAME_YELLOW = vec3(1.0, 0.8, 0.15);
const int FLAME_RUNGS = 6;
// How wide, against its depth, the wedge is in which a box blends its two
// nearest edges.
const float MEDIAL_BLEND = 2.0;
const float PASS_BAKE = 1.0;
const float PASS_RELIGHT = 2.0;
// The steepest lean of fine relief the baked body can hold.
const float BAKED_SLOPE = 4.0;
const vec3 CHAR_COLOR = vec3(0.07, 0.06, 0.055);
const vec3 EMBER_COLOR = vec3(1.0, 0.36, 0.06);
// How far into the scorched band embers reach, as a share of its depth.
const float EMBER_REACH = 0.7;
const vec3 FLAME_BLUE = vec3(0.02, 0.1, 0.85);
const float EFFECT_NEON = 1.0;
const float EFFECT_FLAME = 2.0;
const float VESSEL_GLASS = 1.0;
const float VESSEL_LIQUID = 2.0;
// Thickness of a vessel's wall in pixels.
const float VESSEL_WALL = 2.5;

const float TEXTURE_WOOD = 1.0;
const float TEXTURE_METAL = 2.0;
const float TEXTURE_PLASTIC = 3.0;
const float TEXTURE_STONE = 4.0;
const float TEXTURE_MARBLE = 5.0;
const int FBM_OCTAVES = 4;
const float TAU = 6.28318531;

float hash(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

// Smooth value noise in [0, 1].
float valueNoise(vec2 p) {
  vec2 cell = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float top = mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x);
  float bottom =
      mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), f.x);
  return mix(top, bottom, f.y);
}

// Several octaves of value noise, in [0, 1].
float fbm(vec2 p) {
  float total = 0.0;
  float weight = 0.5;
  for (int octave = 0; octave < FBM_OCTAVES; octave++) {
    total += weight * valueNoise(p);
    p = p * 2.03 + 17.0;
    weight *= 0.5;
  }
  return total / 0.9375;
}

// Every texture returns what it does to the surface at a point: xy leans
// the normal, z is how much of the second colour shows, w is added to the
// roughness.

// Wood. Figure: ring spacing in pixels, waviness, contrast, and how far the
// rings arch into the cathedrals of a plain-sawn board (0 is straight grain).
vec4 woodTexture(vec2 q) {
  float spacing = max(uFigure.x, 1.0);
  float warp = fbm(q * vec2(0.008, 0.04)) - 0.5;
  float across = q.y + uFigure.w * 0.0045 * q.x * q.x + warp * uFigure.y * 60.0;
  float ring = 0.5 + 0.5 * sin(across / spacing * TAU);
  float late = ring * ring;
  float pores = valueNoise(q * vec2(0.03, 1.9));
  float fibre = valueNoise(q * vec2(0.12, 5.0) + 7.0);
  float second = uFigure.z * (0.72 * late + 0.22 * pores + 0.08 * fibre);
  float ridge = (late - 0.3) * 0.10 + (pores - 0.5) * 0.12;
  return vec4(0.0, ridge, clamp(second, 0.0, 1.0), 0.10);
}

// Metal. Figure: how strongly it is brushed (0 is polished), fineness of
// the brushing.
vec4 metalTexture(vec2 q) {
  float fineness = max(uFigure.y, 0.1);
  float streak = valueNoise(q * vec2(0.022, 2.4 * fineness));
  float scratch = valueNoise(q * vec2(0.16, 7.0 * fineness) + 31.0);
  float ridge = ((streak - 0.5) * 0.30 + (scratch - 0.5) * 0.22) * uFigure.x;
  return vec4(0.0, ridge, 0.12 * uFigure.x * streak,
              mix(-0.26, -0.10, uFigure.x));
}

vec4 plasticTexture(vec2 q) {
  vec2 pits = vec2(valueNoise(q * 1.5 + 11.0), valueNoise(q * 1.5 + 47.0));
  return vec4((pits - 0.5) * 0.22, 0.0, -0.04);
}

// The dark mineral grains in a stone such as granite: small rounded
// crystals of differing size and darkness with soft edges, each sitting
// somewhere inside its own cell of a grid that drifts, so they never line
// up.
float mineralFlecks(vec2 q, float amount) {
  vec2 drift = vec2(valueNoise(q * 0.13 + 3.0), valueNoise(q * 0.13 + 61.0));
  vec2 grid = (q + (drift - 0.5) * 9.0) * 0.22;
  vec2 cell = floor(grid);
  float present = step(1.0 - 0.4 * amount, hash(cell));
  vec2 centre = cell + 0.4 + 0.2 * vec2(hash(cell + 13.0), hash(cell + 57.0));
  float size = 0.16 + 0.24 * hash(cell + 91.0);
  float depth = 0.35 + 0.65 * hash(cell + 7.0);
  return present * depth *
      (1.0 - smoothstep(0.35 * size, size, length(grid - centre)));
}

// Stone. Figure: mottling, flecks, banding, and the elongated pits of a
// stone such as travertine.
vec4 stoneTexture(vec2 q) {
  float mottle = fbm(q * 0.045);
  float fleck = mineralFlecks(q, uFigure.y);
  float band = 0.5 + 0.5 * sin(q.y * 0.22 + fbm(q * vec2(0.01, 0.05)) * 8.0);
  float pit =
      uFigure.w * smoothstep(0.70, 0.88, valueNoise(q * vec2(0.07, 0.3) + 3.0));
  vec2 chips = vec2(fbm(q * 0.11 + 5.0), fbm(q * 0.11 + 29.0)) - 0.5;
  float second = uFigure.x * 0.9 * max(mottle - 0.3, 0.0) + 0.6 * fleck +
      uFigure.z * 0.5 * band + 0.75 * pit;
  return vec4(chips * 0.5 * uFigure.x + vec2(0.0, pit * 0.5),
              clamp(second, 0.0, 1.0), mix(0.30, 0.10, uFigure.z));
}

// Marble. Figure: vein density, vein sharpness, turbulence, clouding.
vec4 marbleTexture(vec2 q) {
  vec2 wander = vec2(fbm(q * 0.011), fbm(q * 0.011 + 41.0)) - 0.5;
  float broad = (q.x * 0.6 + q.y * 0.8) * 0.012 * uFigure.x * TAU +
      (wander.x * 4.0 + fbm(q * 0.03) * 1.5) * uFigure.z;
  float ridge = 1.0 - abs(sin(broad));
  // Veins fade in and out along their length, as they do in a slab.
  float reach = smoothstep(0.32, 0.68, fbm(q * 0.013 + 7.0));
  float vein = pow(ridge, mix(6.0, 30.0, uFigure.y)) * (0.3 + 0.7 * reach);
  float fine = (q.y * 0.5 - q.x * 0.7) * 0.019 * uFigure.x * TAU +
      wander.y * 3.5 * uFigure.z;
  float fineReach = smoothstep(0.45, 0.75, fbm(q * 0.02 + 23.0));
  float hairline = 0.6 * pow(1.0 - abs(sin(fine)), 34.0) * fineReach;
  float cloud = uFigure.w * 0.5 * ridge * ridge * reach;
  return vec4(0.0, 0.0, clamp(vein * 0.9 + hairline + cloud, 0.0, 1.0),
              -0.18);
}

vec4 sampleTexture(float kind, vec2 q) {
  if (kind < TEXTURE_WOOD + 0.5) return woodTexture(q);
  if (kind < TEXTURE_METAL + 0.5) return metalTexture(q);
  if (kind < TEXTURE_PLASTIC + 0.5) return plasticTexture(q);
  if (kind < TEXTURE_STONE + 0.5) return stoneTexture(q);
  return marbleTexture(q);
}

const int SCRATCH_PASSES = 4;
// How much narrower than it is long the most drawn-out dent is, and how far
// the outline of a dent wanders in and out as a share of its size.
const float DENT_SQUASH = 2.8;
const float DENT_LUMPINESS = 0.7;
// Half-width of a fissure itself and of the band around it that counts as
// beside it, in the units of the noise that draws it.
const float FISSURE_NEAR = 0.11;

// The wandering fissures of cracked stone: a line of [halfWidth] that runs
// only through some patches, more of them as the wear gets [heavy].
float fissureAt(vec2 q, float halfWidth, float heavy) {
  float line = smoothstep(halfWidth, 0.0, abs(fbm(q * 0.017 + 201.0) - 0.5));
  return line * smoothstep(0.5, 0.62, fbm(q * 0.011 + 303.0) + 0.35 * heavy);
}

// How readily a substance fractures into fissures.
float fissuring(float kind) {
  if (kind > TEXTURE_MARBLE - 0.5) return 1.0;
  if (kind > TEXTURE_STONE - 0.5) return 0.8;
  return 0.0;
}

// The marks left on a body, each kind from a few faint ones at a low amount
// to a ragged surface at 1. [abrasion] is what rubbing and dragging leave:
// scratches, gouges and scuffed patches. [impact] is what knocks leave:
// dents, pits, chipped edges and cracks. [edgeDistance] is how far inside the body's edge the point lies. Returns the lean given
// to the normal in xy, what the colour is multiplied by in z and what is
// added to the roughness in w.
//
// [hollows] describes the terrain for anything lying on top: x is how deep
// inside a groove, pit, chip or crack the point is, and y is how sheltered
// it is by one nearby. The second is only worked out when [wantShelter] is
// set.
vec4 imperfections(float kind, vec2 q, float abrasion, float impact,
                   float edgeDistance, bool wantShelter,
                   out vec2 hollows) {
  hollows = vec2(0.0);
  vec2 lean = vec2(0.0);
  float shade = 1.0;
  float rough = 0.0;
  float scoured = abrasion * abrasion;
  float battered = impact * impact;

  // How each kind of flaw suits the substance. Wood dents, scuffs and
  // splits along its grain; metal takes hairline scratches and dents;
  // plastic scuffs; stone and marble chip, pit and crack.
  float scratching = 0.7;
  float fineness = 1.0;
  float denting = 1.0;
  float pitting = 0.1;
  float scuffing = 0.8;
  float chipping = 0.8;
  float cracking = 1.0;
  float crackAlongGrain = 1.0;
  if (kind > TEXTURE_MARBLE - 0.5) {
    scratching = 0.4;
    denting = 0.0;
    pitting = 0.5;
    scuffing = 0.7;
    chipping = 0.9;
    crackAlongGrain = 0.0;
  } else if (kind > TEXTURE_STONE - 0.5) {
    scratching = 0.3;
    denting = 0.2;
    pitting = 1.0;
    scuffing = 0.6;
    chipping = 1.0;
    cracking = 0.8;
    crackAlongGrain = 0.0;
  } else if (kind > TEXTURE_PLASTIC - 0.5) {
    scratching = 1.0;
    denting = 0.4;
    pitting = 0.0;
    scuffing = 1.0;
    chipping = 0.3;
    cracking = 0.0;
  } else if (kind > TEXTURE_METAL - 0.5) {
    scratching = 1.0;
    fineness = 0.55;
    denting = 0.9;
    pitting = 0.5;
    scuffing = 0.5;
    chipping = 0.15;
    cracking = 0.0;
  }

  // Scratches run in several directions, each one a separate stroke. A
  // stroke starts thin, swells where the thing that made it bit deepest and
  // thins out again, bends a little along its length, and is a rounded
  // groove in cross-section. A few strokes are gouges.
  // Scratches come from events: something dragged the same way again and
  // again leaves most of them running one way and gathered where it
  // happened. The first pass is that habitual damage; each later pass is a
  // rarer event that strays further from its direction and has patches of
  // its own.
  for (int pass = 0; pass < SCRATCH_PASSES; pass++) {
    float turn = pass == 0 ? 0.0 : (pass == 1 ? 0.35 : (pass == 2 ? -0.6 : 1.57));
    float angle = uScratch.x + turn * uScratch.y;
    vec2 along = vec2(cos(angle), sin(angle));
    vec2 across = vec2(-along.y, along.x);
    float lane = dot(q, across) / 7.0 + 13.0 * float(pass);
    float id = floor(lane) + 101.0 * float(pass);
    float share = pass == 0 ? 1.0 : mix(0.75, 0.3, float(pass) / 3.0);
    float cluster = fbm(q * 0.011 + 37.0 * float(pass) + 5.0);
    float gathered = smoothstep(0.42, 0.62, cluster) * 1.9;
    float frequency = share * mix(1.0, gathered, uScratch.z);

    // Most strokes are short nicks and a few are long drags: squaring the
    // chance skews the lengths that way.
    float lengthChance = hash(vec2(id, 5.0));
    float strokeLength = mix(22.0, 340.0, lengthChance * lengthChance);
    float position = dot(q, along) / strokeLength + hash(vec2(id, 3.0)) * 7.0;
    float stroke = floor(position);
    float present = step(1.0 - min(0.7 * abrasion * scratching * frequency, 0.95),
                         hash(vec2(id, stroke + 7.0)));
    float gouge = step(1.0 - 0.2 * scoured * scratching,
                       hash(vec2(id + 23.0, stroke)));

    // How far along the stroke this point is, from 0 to 1, or outside it.
    float begins = 0.12 * hash(vec2(stroke, id + 1.0));
    float extent = mix(0.15, 0.95, hash(vec2(id + 2.0, stroke)));
    float travel = (fract(position) - begins) / extent;
    float within = step(0.0, travel) * step(travel, 1.0);
    travel = clamp(travel, 0.0, 1.0);

    // The swell: zero at both ends, greatest at a point of its own.
    float deepest = mix(0.25, 0.75, hash(vec2(stroke + 4.0, id)));
    float swell = smoothstep(0.0, deepest, travel) *
        (1.0 - smoothstep(deepest, 1.0, travel));

    float bend = (hash(vec2(id + 9.0, stroke)) - 0.5) * 0.7;
    float waver = 0.04 * sin(travel * 9.0 + hash(vec2(stroke, id)) * TAU);
    float offset = fract(lane) - 0.5 -
        (hash(vec2(id, 11.0)) - 0.5) * 0.3 -
        bend * 4.0 * travel * (1.0 - travel) * 0.25 - waver;

    float widest = mix(0.07, 0.2, abrasion) * fineness * (1.0 + 2.2 * gouge);
    float width = widest * (0.12 + 0.88 * swell);
    float reach = abs(offset) / max(width, 0.0001);
    float groove = present * within * swell * (1.0 - smoothstep(0.6, 1.0, reach));
    float depth = mix(0.5, 1.3, abrasion) * (1.0 + 1.4 * gouge);
    lean += across * groove * depth * clamp(offset / max(width, 0.0001), -1.0, 1.0);
    shade += groove * (0.14 - 0.4 * gouge) * (1.0 - reach * reach);
    rough += groove * 0.2;
    hollows.x += groove * (0.4 + 0.6 * gouge);
  }

  // Dents, large and sparse.
  vec2 cell = floor(q / 30.0);
  float dented = step(1.0 - 0.7 * impact * denting, hash(cell + 19.0));
  vec2 centre =
      (cell + 0.25 + 0.5 * vec2(hash(cell + 2.0), hash(cell + 5.0))) * 30.0;
  vec2 fromCentre = q - centre;
  float radius = 3.0 + 9.0 * hash(cell + 9.0) * (0.4 + 0.6 * impact);
  // No two knocks land alike: each dent is drawn out along a direction of
  // its own by an amount of its own, and its outline is uneven.
  float turn = hash(cell + 27.0) * TAU;
  vec2 struck = vec2(cos(turn), sin(turn));
  vec2 beside = vec2(-struck.y, struck.x);
  float squash = mix(1.0, DENT_SQUASH, hash(cell + 33.0));
  vec2 local = vec2(dot(fromCentre, struck), dot(fromCentre, beside) * squash);
  float lumpy = 1.0 +
      DENT_LUMPINESS * (valueNoise(q * 0.3 + cell * 7.0 + 150.0) - 0.5);
  float dent = dented * smoothstep(radius, 0.0, length(local) * lumpy);
  vec2 slope = struck * local.x + beside * local.y * squash;
  lean -= normalize(slope + 0.0001) * dent * mix(0.6, 1.4, impact);
  shade -= dent * 0.2;
  hollows.y += dent * 0.5;

  // Pits, small and many, which only appear once the surface is rough.
  vec2 pitCell = floor(q / 9.0);
  float pitted = step(1.0 - 0.45 * battered * pitting, hash(pitCell + 61.0));
  vec2 pitCentre =
      (pitCell + 0.2 + 0.6 * vec2(hash(pitCell + 4.0), hash(pitCell + 8.0))) *
      9.0;
  vec2 fromPit = q - pitCentre;
  float pit = pitted * smoothstep(1.2 + 2.0 * hash(pitCell + 15.0), 0.0,
                                  length(fromPit));
  lean -= normalize(fromPit + 0.0001) * pit * 1.1;
  shade -= pit * 0.3;
  hollows.x += pit;
  hollows.y += 0.15 * pitted * smoothstep(6.0, 0.0, length(fromPit));

  // Scuffed patches where the finish has worn away: duller and uneven.
  float scuff =
      scoured * scuffing * smoothstep(0.42, 0.7, fbm(q * 0.035 + 71.0));
  vec2 scuffGrain =
      vec2(valueNoise(q * 0.9 + 3.0), valueNoise(q * 0.9 + 57.0)) - 0.5;
  lean += scuffGrain * scuff * 0.7;
  shade *= 1.0 - 0.22 * scuff * valueNoise(q * 0.5 + 9.0);
  rough += 0.35 * scuff;
  hollows.y += 0.3 * scuff;

  // Chips knocked out of the edges.
  float nearEdge = smoothstep(2.0 + 10.0 * impact, 0.0, edgeDistance);
  float chipNoise = valueNoise(q * 0.22 + 111.0);
  float chip = chipping * nearEdge * smoothstep(1.0 - 0.75 * impact, 1.05 - 0.6 * impact,
                                     chipNoise + 0.35 * nearEdge);
  vec2 chipGrain =
      vec2(valueNoise(q * 0.6 + 21.0), valueNoise(q * 0.6 + 83.0)) - 0.5;
  lean += chipGrain * chip * 1.6;
  shade *= 1.0 - 0.45 * chip;
  rough += 0.4 * chip;
  hollows += vec2(0.6, 1.0) * chip;

  // Cracks. Wood splits in long checks along its grain; stone and marble
  // fracture along wandering fissures.
  float checkLane = (q.y + (fbm(q * vec2(0.006, 0.03) + 5.0) - 0.5) * 30.0) /
      26.0;
  float checkId = floor(checkLane);
  float checked = step(1.0 - 0.55 * battered, hash(vec2(checkId, 131.0)));
  float checkRun = smoothstep(
      0.45, 0.6, valueNoise(vec2(q.x * 0.006 + checkId * 3.7, checkId)));
  float check = checked * checkRun *
      smoothstep(0.07, 0.0, abs(fract(checkLane) - 0.5));
  float fissure = crackAlongGrain < 0.5
      ? fissureAt(q, 0.012 + 0.012 * impact, battered)
      : 0.0;
  float crack = cracking * battered * mix(fissure, check, crackAlongGrain);
  lean += vec2(crackAlongGrain < 0.5 ? 0.6 : 0.0, 0.9) * crack *
      sign(fract(checkLane) - 0.5);
  shade *= 1.0 - 0.7 * crack;
  rough += 0.3 * crack;
  hollows.x += crack;
  if (wantShelter) {
    float besideCheck = checked * checkRun *
        smoothstep(0.38, 0.0, abs(fract(checkLane) - 0.5));
    float besideFissure =
        crackAlongGrain < 0.5 ? fissureAt(q, FISSURE_NEAR, battered) : 0.0;
    hollows.y +=
        cracking * battered * mix(besideFissure, besideCheck, crackAlongGrain);
  }
  hollows = clamp(hollows, 0.0, 1.0);

  return vec4(lean, max(shade, 0.15), rough);
}

const vec3 MOSS_DEEP = vec3(0.10, 0.17, 0.06);
const vec3 MOSS_BRIGHT = vec3(0.40, 0.55, 0.16);
const vec3 MOSS_SUNLIT = vec3(0.58, 0.69, 0.20);
const vec3 MOSS_YOUNG = vec3(0.50, 0.68, 0.18);
const vec3 MOSS_DRY = vec3(0.52, 0.47, 0.22);
// Size in pixels of the sprigs that make up the pile of the moss, and how
// far they fray its edge.
const float MOSS_SPRIG = 2.6;
const float MOSS_FRAY = 0.16;
const vec3 GRASS_ROOT = vec3(0.12, 0.24, 0.07);
const vec3 GRASS_TIP = vec3(0.50, 0.70, 0.24);
const vec3 GRASS_COOL = vec3(0.27, 0.50, 0.25);
const vec3 LEAF_COLOR = vec3(0.24, 0.42, 0.13);
const vec3 GRASS_STRAW = vec3(0.74, 0.68, 0.40);
const vec3 FLOWER_HEART = vec3(0.96, 0.78, 0.18);
// Width of a column of grass and the tallest a blade grows, in pixels.
const vec2 GRASS_CELL = vec2(3.5, 30.0);
const float FLOWER_CELL = 40.0;
// What a flower reports a point to be when it is not on a petal.
const float FLOWER_HEART_TONE = 2.0;
const float FLOWER_LEAF_TONE = 3.0;
// How light behaves in anything grown: how far it wraps round onto faces
// turned away from it, how much of it passes through them, and how far what
// passes through takes on their pure colour.
const float SUBSURFACE_WRAP = 0.6;
const float SUBSURFACE_GLOW = 0.5;
const float SUBSURFACE_SATURATION = 0.45;
// Stands for how damp a spot must be for growth that is not there at all.
const float NO_GROWTH = 9.0;
// How much damper than the edge of the moss or grass a spot must be for a
// flower to root there, so flowers sit within the growth and not on its
// fringe.
const float MOSS_ROOTING = 0.05;
const float GRASS_ROOTING = 0.1;
const float WATER_ROUGHNESS = 0.2;
// How strongly the height of a drop in the rain map leans its surface.
const float RAIN_RELIEF = 0.9;
// How steeply the edge of a trail of water stands off the body.
const float TRAIL_RELIEF = 0.6;
// The amount of water in the rain map taken as the water's edge, and the
// most a single drop adds at its middle.
const float RAIN_EDGE = 0.3;
const float RAIN_FULLEST = 0.75;
// How far, in pixels, a drop shifts the view of what lies beneath it.
const float WATER_REFRACTION = 7.0;

// Broad damp and dry patches, in [0, 1].
float dampAt(vec2 pos) {
  return 0.65 * valueNoise(pos * 0.021 + 311.0) +
      0.35 * valueNoise(pos * 0.07 + 17.0);
}

// How well a spot holds water and soil, for deciding where something can
// take root: the damp patches, plus the fissures of cracked stone.
// [crackShare] is how much the surface has fissured.
float moistureAt(vec2 pos, float textureScale, float crackShare, float heavy) {
  float damp = dampAt(pos);
  if (crackShare <= 0.0) return damp;
  return damp +
      0.7 * crackShare * fissureAt(pos / textureScale, FISSURE_NEAR, heavy);
}

// Moss grows as rounded cushions stored side by side. Each cushion is a
// dome about the nearest of a scatter of points, one to a cell of [size]
// pixels. Returns the lean of the dome in xy and its height in z, from 0 in
// the gaps between cushions to 1 on their crowns.
vec3 mossCushionAt(vec2 pos, float size) {
  vec2 g = pos / size;
  vec2 cell = floor(g);
  vec2 nearest = vec2(0.0);
  float least = 8.0;
  for (int row = 0; row < 3; row++) {
    for (int column = 0; column < 3; column++) {
      vec2 id = cell + vec2(float(column) - 1.0, float(row) - 1.0);
      vec2 offset = id + vec2(hash(id + 211.0), hash(id + 223.0)) - g;
      float d = dot(offset, offset);
      if (d < least) {
        least = d;
        nearest = offset;
      }
    }
  }
  float share = clamp(sqrt(least) / 0.72, 0.0, 1.0);
  return vec3(-nearest / 0.72 * share, sqrt(1.0 - share * share));
}

// Blades of grass growing against gravity out of the wettest spots. Each
// is a folded blade of its own breadth that swells from its root, tapers
// to a point and droops to one side. Returns the lean across the blade in
// xy, how much it covers the point in z and how far up the blade the point
// is in w. [thatch] is how deep in the shade at the foot of a tuft the
// point lies.
vec4 grassAt(vec2 pos, vec2 down, float amount, float textureScale,
             float crackShare, float heavy, out float thatch) {
  vec2 side = vec2(-down.y, down.x);
  vec2 up = -down;
  vec2 g = vec2(dot(pos, side), dot(pos, up));
  vec2 cell = floor(g / GRASS_CELL);
  float starts = mix(1.3, 0.25, amount);
  vec4 best = vec4(0.0);
  thatch = 0.0;
  for (int row = 0; row < 2; row++) {
    for (int column = 0; column < 5; column++) {
      vec2 id = cell + vec2(float(column) - 2.0, float(row) - 1.0);
      vec2 root =
          (id + vec2(hash(id + 3.0), 0.8 * hash(id + 7.0))) * GRASS_CELL;
      float moisture =
          moistureAt(side * root.x + up * root.y, textureScale, crackShare,
                     heavy) +
          0.25 * (hash(id + 11.0) - 0.5);
      // Grass comes up in tufts: a tuft is a short run of columns whose
      // blades all grow, with bare columns between.
      float tuft = smoothstep(
          0.42 - 0.45 * amount, 0.62 - 0.45 * amount,
          valueNoise(vec2(id.x * 0.16, id.y * 0.7) + 601.0));
      float grows = smoothstep(starts, starts + 0.2, moisture) * tuft;
      float height = GRASS_CELL.y * (0.3 + 0.7 * hash(id + 19.0)) * grows *
          (0.45 + 0.55 * amount);
      float standing = step(1.5, height);
      float t = (g.y - root.y) / max(height, 0.001);
      float along = clamp(t, 0.0, 1.0);
      float bend = (hash(id + 23.0) - 0.5) * 3.2 * GRASS_CELL.x;
      float broad = mix(0.8, 1.7, hash(id + 37.0));
      float halfWidth = broad * (0.3 + 0.7 * smoothstep(0.0, 0.15, along)) *
          (1.0 - 0.85 * along * along);
      float offset = g.x - root.x - bend * t * t;
      float cover = standing * step(0.0, t) * step(t, 1.0) *
          (1.0 - smoothstep(halfWidth - 0.45, halfWidth + 0.45, abs(offset)));
      vec2 fromRoot = vec2(g.x - root.x, (g.y - root.y) * 0.7);
      thatch = max(thatch,
                   standing * (1.0 - smoothstep(1.0, 6.0, length(fromRoot))));
      if (cover > best.z) {
        // A blade is folded along its middle, so each half faces its own
        // way. The whole part of w is the blade's own shade; the rest is
        // how far up it the point is.
        float across = clamp(offset / max(halfWidth, 0.001), -1.0, 1.0);
        best = vec4(side * (0.35 * across + 0.3 * sign(offset)), cover,
                    floor(hash(id + 31.0) * 8.0) + 0.999 * along);
      }
    }
  }
  return best;
}

// How much of a point an ellipse covers, given the point in the ellipse's
// own frame, where its outline is at a distance of 1.
float ellipseCover(vec2 within) {
  return 1.0 - smoothstep(0.78, 1.0, dot(within, within));
}

// A flower lying open on the growth, one to a cell at most: a ring of
// separate petals round a domed heart, over a pair of leaves. A low amount
// gives a few closed buds; a high one gives many, fully open. Returns the
// lean of the surface in xy, how much the flower covers the point in z, and
// in w what the point is: the tone of a petal from 0 at its base to 1 at
// its tip, the heart of the flower, or a leaf with its own shade added.
// [shadow] is how deep in the flower's shade the point lies.
//
// A flower roots in moss or grass where there is any: [groundStarts] holds
// how damp a spot must be for each to grow there, or NO_GROWTH for one that
// is absent. With neither, it roots wherever a spot is damper than
// [starts].
vec4 flowerAt(vec2 pos, float amount, float starts, vec2 groundStarts,
              float textureScale, float crackShare, float heavy,
              out float shadow) {
  vec2 cell = floor(pos / FLOWER_CELL);
  vec2 centre =
      (cell + 0.35 + 0.3 * vec2(hash(cell + 2.0), hash(cell + 9.0))) *
      FLOWER_CELL;
  float moisture = moistureAt(centre, textureScale, crackShare, heavy);
  float inMoss = step(groundStarts.x + MOSS_ROOTING, dampAt(centre));
  float inGrass = step(groundStarts.y + GRASS_ROOTING, moisture);
  float rooted = min(groundStarts.x, groundStarts.y) < NO_GROWTH
      ? max(inMoss, inGrass)
      : step(starts, moisture);
  float planted = step(1.0 - 0.9 * amount, hash(cell + 131.0)) * rooted;
  float open = clamp(amount * 1.7 - 0.7 * hash(cell + 17.0), 0.0, 1.0);
  float radius = (5.0 + 5.0 * hash(cell + 29.0)) * mix(0.35, 1.0, open);
  vec2 d = pos - centre;
  float reach = length(d);
  vec2 outward = d / max(reach, 0.001);
  shadow = planted * (1.0 - smoothstep(radius * 0.7, radius * 1.45, reach));

  // Each petal is an ellipse lying along its own spoke, a little longer or
  // shorter than its neighbours and tucked under the next one round.
  float count = 5.0 + floor(3.0 * hash(cell + 41.0));
  float sector = TAU / count;
  float turned = (atan(d.y, d.x) + hash(cell + 53.0) * TAU) / sector;
  float spoke = mod(floor(turned), count);
  float aside = (fract(turned) - 0.5) * sector;
  float longest =
      radius * (0.8 + 0.2 * hash(vec2(spoke, cell.x + 7.0 * cell.y)));
  vec2 inPetal = vec2((reach * cos(aside) - 0.55 * longest) / (0.5 * longest),
                      reach * sin(aside) / (1.05 * longest * sin(0.5 * sector)));
  float petal = ellipseCover(inPetal);
  float tone = clamp(0.25 + 0.75 * reach / radius, 0.0, 1.0);
  tone *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.14, abs(inPetal.y)));
  tone *= mix(0.72, 1.0, smoothstep(-0.5, -0.2, aside / sector));
  vec2 lean = outward * inPetal.x * 0.45 +
      vec2(-outward.y, outward.x) * inPetal.y * 0.5;

  float heartRadius = 0.24 * radius;
  float heart = 1.0 - smoothstep(heartRadius - 0.6, heartRadius + 0.2, reach);
  if (heart > 0.5) {
    return vec4(d / heartRadius * 0.6, planted * max(heart, petal),
                FLOWER_HEART_TONE);
  }

  float leaf = 0.0;
  vec2 leafLean = vec2(0.0);
  float leafShade = 0.0;
  for (int which = 0; which < 2; which++) {
    float leafTurn = hash(cell + 61.0 + 13.0 * float(which)) * TAU;
    vec2 axis = vec2(cos(leafTurn), sin(leafTurn));
    vec2 blade = vec2(-axis.y, axis.x);
    vec2 inLeaf = vec2((dot(d, axis) - 0.95 * radius) / (0.45 * radius),
                       dot(d, blade) / (0.2 * radius));
    float covers = ellipseCover(inLeaf) * smoothstep(0.3, 0.6, open);
    if (covers > leaf) {
      leaf = covers;
      leafLean = blade * sign(inLeaf.y) * 0.4;
      leafShade = 0.5 + 0.5 * smoothstep(0.0, 0.25, abs(inLeaf.y));
    }
  }
  if (petal < 0.3 && leaf > 0.0) {
    return vec4(leafLean, planted * leaf, FLOWER_LEAF_TONE + 0.99 * leafShade);
  }
  return vec4(lean, planted * max(petal, heart), tone);
}

// A scatter of round beads of still water, one to a cell at most. Returns
// the lean of the bead's dome in xy and how much it covers the point in z.
vec3 beadsAt(vec2 pos, float cellSize, float amount, float seed) {
  vec2 cell = floor(pos / cellSize) + seed;
  vec2 centre =
      (floor(pos / cellSize) + 0.3 +
       0.4 * vec2(hash(cell + 2.0), hash(cell + 4.0))) *
      cellSize;
  float radius = cellSize * (0.1 + 0.2 * hash(cell + 15.0));
  vec2 d = (pos - centre) / max(radius, 0.001);
  float share = length(d);
  float cover = step(1.0 - amount, hash(cell + 21.0)) *
      (1.0 - smoothstep(0.75, 1.0, share));
  return vec3(d * share, cover);
}

vec4 rainMapAt(vec2 position) {
  vec2 uv = clamp(position / uSize, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uRainMap, uv);
}

// The rain at a point, read from the map. Every drop adds a mound of water
// to the map, and the water's edge is wherever the total passes RAIN_EDGE,
// so drops that come close join into one body. Returns the lean of the
// water's surface in xy, how much the water covers the point in z, and how
// wet a trail has left it in w.
//
// The surface leans away from where the water is deepest, steeply at its
// edge and not at all at its middle, like the dome of a drop.
//
// A trail is a low ridge of water left along the path of a drop. Its own
// lean, away from its middle and towards its edges, is set in [trailLean].
//
// The water's edge is not a clean curve. [ripple] is how far the body
// beneath pushes it in and out, so that a drop's outline wavers as it
// crosses the body, more on a rough one than a slick one.
vec4 rainAt(vec2 position, float ripple, out vec2 trailLean) {
  vec4 here = rainMapAt(position);
  float wavering = 0.65 * valueNoise(position * 0.3 + 571.0) +
      0.35 * valueNoise(position * 0.8 + 233.0) - 0.5;
  here.r += ripple * wavering * smoothstep(0.08, 0.25, here.r);
  vec4 right = rainMapAt(position + vec2(1.0, 0.0));
  vec4 left = rainMapAt(position - vec2(1.0, 0.0));
  vec4 below = rainMapAt(position + vec2(0.0, 1.0));
  vec4 above = rainMapAt(position - vec2(0.0, 1.0));
  vec2 rise = vec2(right.r - left.r, below.r - above.r);
  vec2 ridge = vec2(right.g - left.g, below.g - above.g);
  float sharpness = length(ridge);
  trailLean = sharpness > 0.0005
      ? -ridge / sharpness * min(sharpness * 2.0, 1.0) * TRAIL_RELIEF
      : vec2(0.0);
  float steepness = length(rise);
  vec2 downhill = steepness > 0.0005 ? -rise / steepness : vec2(0.0);
  float depth =
      clamp((here.r - RAIN_EDGE) / (RAIN_FULLEST - RAIN_EDGE), 0.0, 1.0);
  vec2 lean = downhill * RAIN_RELIEF * (1.0 - depth) * (1.0 + wavering);
  return vec4(lean, smoothstep(RAIN_EDGE - 0.04, RAIN_EDGE + 0.04, here.r),
              here.g);
}

// Returns (distance, outward gradient) of the rounded box centred on origin.
//
// Deep inside a box the nearest edge changes along the diagonal running in
// from each corner, and a body whose bevel reaches that far would show the
// change as a crease. So the two edges are blended into each other there,
// over a wedge that narrows to nothing at the edges themselves, where the
// distance stays exact.
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

// A tube of glowing gas: white-hot along its middle, its own colour at the
// glass, with a halo that falls away outside it. [distance] is the signed
// distance to the body. Returns a premultiplied colour brighter than its
// alpha, so the glow adds to whatever is behind it.
vec4 neon(float distance, float bevel, vec2 halfSize, float time,
          vec3 highlights) {
  float intensity = uEffect.y;
  float tube = uEffect.z;
  float stutter = step(0.9, valueNoise(vec2(time * 11.0, 3.0)));
  float hum = 1.0 - uEffect.w * (0.06 + 0.06 * sin(time * 53.0) + 0.6 * stutter);
  float glowing = intensity * hum;

  float halfTube =
      tube > 0.0 ? tube * 0.5 : min(bevel, min(halfSize.x, halfSize.y));
  float d = tube > 0.0 ? abs(distance + halfTube) - halfTube : distance;
  float core = clamp(-d / halfTube, 0.0, 1.0);
  float body = clamp(0.5 - d * uForm.z, 0.0, 1.0);

  vec3 gas = uEffectColor * uEffectColor;
  vec3 unlit = gas * 0.12;
  vec3 lit = gas * (0.75 + 0.6 * core) + vec3(core * core * 0.9);
  vec3 tubeColor = sqrt(mix(unlit, lit, glowing)) + highlights * 0.4;

  float outside = max(d, 0.0);
  float halo = glowing * (0.55 * exp(-outside / 5.0) + 0.3 * exp(-outside / 16.0));
  vec3 haloColor = sqrt(gas) * halo;
  return vec4(tubeColor * body + haloColor * (1.0 - body),
              body + 0.35 * halo * (1.0 - body));
}

// A single number that changes steadily across the body whichever way a
// fire on it is burning, for flicker that differs from place to place.
//
// Nothing about a fire's look is laid out along the way its flames rise:
// were it, turning the fire would swing the whole pattern round with it.
// Its noise is fixed to the body and only drifts along the flow.
float alongRim(vec2 p) {
  return p.x + 0.6 * p.y;
}

// Noise drawn out along [down], for tongues of flame that are longer than
// they are wide. Two readings a little way apart along the flow are
// blended, and the contrast that costs is put back.
float drawnOut(vec2 at, vec2 down, float scale, float stretch) {
  float blended =
      0.5 * (fbm(at * scale) + fbm((at - down * stretch) * scale));
  return clamp(0.5 + (blended - 0.5) * 1.35, 0.0, 1.0);
}

// How strongly a fire round the body lights it at a point along its rim.
float firelight(vec2 p, vec2 side, float time) {
  return uEffect.y *
      (0.8 + 0.2 * valueNoise(vec2(alongRim(p) * 0.015, time * 5.0)));
}

// How far a point is from the column a body sweeps out as it is carried
// [reach] pixels against [down]: everything a flame rooted on the body can
// fill on its way up. Following the whole sweep, and not only where it ends,
// keeps a flame taller than its body joined to it.
float risenFrom(vec2 q, vec2 down, float reach, vec2 halfSize) {
  float nearest = roundedBox(q, halfSize).x;
  for (int rung = 1; rung <= FLAME_RUNGS; rung++) {
    float share = float(rung) / float(FLAME_RUNGS);
    nearest = min(nearest, roundedBox(q + down * reach * share, halfSize).x);
  }
  return nearest;
}

// Fire round the edge of a body that is not itself burning. Flames stand
// off the outline and rise against gravity: each point looks back down the
// way the flames have come, and if the body's edge lies within the height
// the flames reach there, it is in the fire. A low fringe burns all the way
// round, the underside included.
//
// The air over a fire rolls, so the place each point looks from is pushed
// about by noise that streams upwards, further the higher it is. That bends
// the tongues, and noise that eats into them near their tips tears licks
// off to rise on their own. Sparks ride the same stream.
//
// Returns a premultiplied colour that adds to what is behind it, and sets
// [thrown] to how strongly the fire lights the body's rim at this point.
vec4 flames(vec2 p, vec2 halfSize, float distance, float time,
            out float thrown) {
  vec2 down = uEffectDown;
  vec2 side = vec2(-down.y, down.x);
  float intensity = uEffect.y;
  float turbulence = uEffect.w;
  float height = max(uEffectShape.x * intensity, 1.0);
  float outside = max(distance, 0.0);
  float lift = clamp(outside / height, 0.0, 1.0);

  vec2 stream = p + uEffectFlow * 70.0;
  vec2 roll = vec2(fbm(stream * 0.03 + 17.0), fbm(stream * 0.03 + 71.0)) - 0.5;
  vec2 eddy = vec2(valueNoise(stream * 0.11 + vec2(5.0, time * 0.7)),
                   valueNoise(stream * 0.11 + vec2(33.0, -time * 0.9))) -
      0.5;
  vec2 q = p + (roll * 30.0 + eddy * 10.0) * turbulence * (0.2 + lift);

  vec2 rising = q + uEffectFlow * 95.0;
  float tongues =
      drawnOut(rising, down, 0.04, 16.0);
  float reach = height * (0.2 + 1.1 * tongues);
  float soften = 2.0 + 0.16 * height * lift;
  float tongue = 1.0 - smoothstep(-soften, soften,
                                  risenFrom(q, down, reach, halfSize));
  float fringe = 1.0 - smoothstep(0.0, 3.0 + 0.14 * height * tongues,
                                  roundedBox(q, halfSize).x);
  float torn = fbm(rising * 0.06 + 40.0);
  float fade = (1.0 - lift * lift) * smoothstep(-2.5, 1.0, distance);
  float heat = max(tongue, 0.7 * fringe) * fade *
      smoothstep(0.9 * lift - 0.15, 0.9 * lift + 0.25, torn + 0.25);

  // The body of a flame is not one flat sheet: hotter and cooler gas churn
  // through it as it rises, so it is streaked lighter and darker along its
  // length. That churn, how far up the flame the point is and how thin the
  // flame is there together set its temperature, and the temperature sets
  // the colour: deep red where cool, through orange and yellow to near
  // white at its hottest.
  float churn = fbm(rising * 0.075 +
                    90.0);
  float wisp =
      valueNoise(rising * 0.2);
  float inner = clamp(0.15 + 1.2 * churn + 0.4 * (wisp - 0.5), 0.0, 1.3);
  float temperature =
      clamp(heat * (1.0 - 0.75 * lift) * (0.35 + inner), 0.0, 1.0);

  vec3 fire = uEffectColor * uEffectColor;
  vec3 hot = mix(fire, FLAME_WHITE, 0.8);
  vec3 ember = fire * vec3(0.6, 0.1, 0.03);
  vec3 color = mix(ember, fire, smoothstep(0.05, 0.35, temperature));
  color = mix(color, mix(fire, FLAME_YELLOW, 0.5),
              smoothstep(0.3, 0.6, temperature));
  color = mix(color, hot, smoothstep(0.55, 0.9, temperature));
  color *= 0.5 + 0.8 * inner;

  // Where a flame leaves the fuel it burns clean and blue. The blue fades
  // up into the body over a quarter of its height and keeps some of the
  // colour beneath it, so there is no line where one ends.
  float rootFade = 1.0 - smoothstep(0.0, 0.26, lift);
  float root = rootFade * rootFade * smoothstep(0.2, 0.7, heat) *
      (0.5 + 0.5 * valueNoise(vec2(alongRim(p) * 0.09, time * 4.0)));
  color = mix(color, FLAME_BLUE + 0.35 * color, 0.7 * root);
  float glow = smoothstep(0.02, 0.45, heat) * (0.7 + 0.3 * inner);

  // Fire lights the air round it. A soft halo follows the tongues loosely
  // and falls away with distance, adding light without hiding what is
  // behind.
  float flicker =
      0.75 + 0.25 * valueNoise(vec2(alongRim(p) * 0.03, time * 5.0));
  float halo = intensity * flicker * fade *
      exp(-max(risenFrom(q, down, reach * 0.6, halfSize), 0.0) /
          (0.3 * height));
  vec3 haloColor = fire * vec3(1.0, 0.55, 0.25);

  // Sparks are thrown off the tips, so they only show over the top of the
  // body, from where the tongues thin out upwards.
  float headroom = height * 1.5;
  float overTips = smoothstep(0.0, 8.0, roundedBox(p + down * 0.4 * height,
                                                   halfSize).x) *
      (1.0 - smoothstep(-4.0, 4.0, roundedBox(p + down * headroom, halfSize).x));
  vec2 carried = p + uEffectFlow * 120.0 + roll * 40.0 * turbulence;
  vec2 cell = floor(carried / 24.0);
  vec2 speck = carried -
      (cell + 0.2 + 0.6 * vec2(hash(cell + 2.0), hash(cell + 6.0))) * 24.0;
  float spark = intensity * step(0.88, hash(cell + 11.0)) *
      (1.0 - smoothstep(0.5, 1.5, length(speck))) * overTips *
      smoothstep(1.0, 4.0, outside) *
      (1.0 - smoothstep(0.6, 1.0, outside / headroom));

  thrown = firelight(p, side, time);
  return vec4(sqrt(color) * glow + sqrt(haloColor) * 0.5 * halo * (1.0 - glow) +
                  sqrt(hot) * spark,
              0.5 * glow + 0.1 * halo + 0.5 * spark);
}

// The liquid in a vessel: how much of it covers the point in a, and its
// colour in rgb. Nothing is simulated. The surface is a flat plane facing
// uLiquid.xy, set at the height that leaves the vessel as full as it should
// be, rippled by sine waves when the liquid is disturbed and drawn up a
// little where it meets the glass.
//
// The vessel is seen from slightly above, so the surface shows as a pale
// ellipse reaching back from its near edge. Below it the liquid darkens
// through the depth of the vessel as light is absorbed, brightens on the
// side the light leaves by, and carries bubbles up when it has been shaken.
// Shaking also raises a head of foam: a layer of stored bubbles standing on
// the surface, thick and lumpy at first, that thins as the bubbles burst.
vec4 liquid(vec2 p, vec2 halfSize, float distance, float time) {
  vec2 up = uLiquid.xy;
  vec2 along = vec2(-up.y, up.x);
  float agitation = uLiquid.z;
  float extent = abs(up.x) * halfSize.x + abs(up.y) * halfSize.y;
  float span = abs(along.x) * halfSize.x + abs(along.y) * halfSize.y;
  float level = (2.0 * uEffectShape.z - 1.0) * (extent - VESSEL_WALL);
  float x = dot(p, along);
  float fromWall = max(-distance - VESSEL_WALL, 0.0);
  float wave = 0.3 * sin(x * 0.05 + time * 1.3) +
      agitation *
          (2.6 * sin(x * 0.09 + time * 5.0) + 1.4 * sin(x * 0.17 - time * 7.3));
  float meniscus = 2.0 * exp(-fromWall / 2.5);
  float depth = level + wave + meniscus - dot(p, up);

  float across = clamp(x / max(span - VESSEL_WALL, 1.0), -1.0, 1.0);
  float back = min(0.16 * span, 14.0) * sqrt(1.0 - across * across);
  float inside = clamp((-distance - VESSEL_WALL) * uForm.z, 0.0, 1.0);
  float body = inside * clamp(depth * uForm.z + 0.5, 0.0, 1.0);
  float cover = inside * clamp((depth + back) * uForm.z + 0.5, 0.0, 1.0);
  float top = cover - body;

  float inward = clamp(-distance / min(halfSize.x, halfSize.y), 0.0, 1.0);
  float thickness = sqrt(inward * (2.0 - inward));
  float density = uEffectShape.w;
  vec3 pure = uVessel.yzw * uVessel.yzw;
  vec3 thin = mix(pure, vec3(1.0), 0.35);
  vec3 absorbed = pure * exp(-(1.0 - pure) * (0.5 + 3.0 * density) * thickness);
  vec3 color = mix(thin, absorbed, 0.35 + 0.65 * thickness);
  color *= 1.0 - 0.25 * clamp(depth / max(extent, 1.0), 0.0, 1.0);
  float leaving = dot(p / halfSize, -uLight.xy);
  color *= 1.0 + 0.45 * smoothstep(-0.1, 0.9, leaving) * thickness;

  // Bubbles: a few always, many after a shake, wobbling as they rise.
  // They rise against gravity along the path they have already taken, not
  // against the swinging surface.
  vec2 lifted = p + uLiquidFlow * 22.0;
  vec2 cell = floor(lifted / 15.0);
  float wobble = 1.5 * sin(time * 3.0 + hash(cell + 3.0) * TAU);
  vec2 fromBubble = lifted + along * wobble -
      (cell + 0.25 + 0.5 * vec2(hash(cell + 7.0), hash(cell + 9.0))) * 15.0;
  float bubbleRadius = 1.0 + 2.2 * hash(cell + 13.0);
  float bubbleShare = length(fromBubble) / bubbleRadius;
  float bubble = step(1.0 - 0.05 - 0.5 * agitation, hash(cell + 17.0)) *
      (1.0 - smoothstep(0.75, 1.0, bubbleShare)) * smoothstep(2.0, 6.0, depth);
  color = mix(color, vec3(1.0), bubble * (0.15 + 0.5 * bubbleShare * bubbleShare));

  // The near edge of the surface is a fine bright line over a dark one.
  float edge = 1.0 - smoothstep(0.0, 1.6, abs(depth));
  color *= 1.0 - 0.2 * edge * body;

  float sheen = 0.5 + 0.5 * clamp(-depth / max(back, 0.5), 0.0, 1.0);
  vec3 surface = mix(thin, vec3(1.0), 0.1 + 0.2 * sheen);
  color = mix(color, surface, top / max(cover, 0.001));
  color = mix(color, vec3(1.0), 0.14 * edge);

  // The head of foam. Its bubbles are stored domes, large ones with small
  // ones between, drifting slowly; each bursts at its own moment as the
  // head settles, which leaves the top ragged.
  float foam = uLiquid.w;
  if (foam > 0.01) {
    vec2 drift = along * sin(time * 0.7) * 1.5;
    vec3 large = mossCushionAt(p + drift, 6.5);
    vec3 fine = mossCushionAt(p - drift + 50.0, 3.2);
    float bubbleHeight = 0.6 * large.z + 0.4 * fine.z;
    float burst = valueNoise(p * 0.12 + 800.0);
    float head = foam * (5.0 + 0.22 * extent) * (0.55 + 0.45 * burst);
    float above = -depth - back * 0.5;
    float crest = head + 2.5 * (bubbleHeight - 0.5);
    float sunk = 2.0 + 3.0 * foam;
    float standing = inside * smoothstep(crest, crest - 1.5, above) *
        smoothstep(-sunk, -sunk + 2.0, above) * smoothstep(0.0, 0.08, foam);
    vec3 cream = mix(vec3(1.0), pure, 0.16);
    vec3 between = mix(cream, pure, 0.45);
    vec3 foamColor = mix(between, cream, bubbleHeight) *
        (0.9 + 0.2 * dot(large.xy, uLight.xy));
    color = mix(color, foamColor, standing);
    cover = max(cover, standing);
  }
  return vec4(color, cover);
}

float interleavedGradientNoise(vec2 pixel) {
  return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

// One tile of the baked body at a point of the surface.
vec4 bakedAt(vec2 position, vec2 tile) {
  vec2 inset = vec2(0.5) / uForm.z;
  vec2 within = clamp(position, inset, uSize - inset);
  vec2 uv = (within + tile * uSize) / uStage.zw;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uBaked, uv);
}

// What the bake writes into [tile]. Leans are small far more often than
// they are steep, so they are stored as square roots to keep the gentle
// ones precise.
vec4 bakedTile(vec2 tile, vec3 color, vec2 lean, float roughness,
               float specularTint, float diffuseShare, vec4 hints,
               float mossCover) {
  if (tile.y < 0.5) {
    if (tile.x < 0.5) return vec4(color, 1.0);
    vec2 stored = 0.5 + 0.5 * sign(lean) *
        sqrt(min(abs(lean), BAKED_SLOPE) / BAKED_SLOPE);
    return vec4(stored, roughness, 1.0);
  }
  if (tile.x < 0.5) {
    return vec4(specularTint, 0.5 * diffuseShare, hints.w, 1.0);
  }
  return vec4(hints.x, hints.z, mossCover, 1.0);
}

void main() {
  vec2 halfSize = uSize * 0.5;
  vec2 coord = FlutterFragCoord().xy;
  bool baking = uStage.y > PASS_BAKE - 0.5 && uStage.y < PASS_BAKE + 0.5;
  bool relit = uStage.y > PASS_RELIGHT - 0.5;
  vec2 tile = vec2(0.0);
  if (baking) {
    tile = min(floor(coord / uSize), vec2(1.0));
    coord -= tile * uSize;
  }
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

  float shoulder = 1.0 - clamp(-box.x / bevel, 0.0, 1.0);
  float slope = min(shoulder * shoulder, MAX_BEVEL_SLOPE);
  vec2 lean = box.yz * slope * relief + (p / halfSize) * crown * sign(relief);
  vec3 normal = normalize(vec3(lean, sqrt(max(1.0 - slope * slope, 0.0))));

  vec3 shapeNormal = normal;
  vec3 surfaceColor = uColor.rgb;
  float diffuseShare = 1.0;
  float finishRoughness = roughness;
  vec4 hints = vec4(0.0);
  float water = 0.0;
  float glint = 0.0;
  bool hinting = overlay < 0.5 && uWorld.z > 0.5;
  bool grown = overlay < 0.5 && uGrowth.x + uGrowth.y + uGrowth.z > 0.0;
  bool watered =
      overlay < 0.5 && (uWater.x + uWater.y > 0.0 || uStage.x > 0.5);
  bool layered = grown || watered || hinting || baking;
  if (layered) {
    hints.y = 0.55 * smoothstep(16.0, 0.0, max(-box.x, 0.0));
  }
  if (uTexture.x > 0.5 && overlay < 0.5 && !relit) {
    float strength = uTexture.z;
    vec2 q = p / max(uTexture.y, 0.05);
    vec4 grain = sampleTexture(uTexture.x, q);
    normal = normalize(normal + vec3(grain.xy * strength, 0.0));
    surfaceColor = mix(surfaceColor, uSecondColor, grain.z * strength);
    roughness = clamp(roughness + grain.w * strength, 0.08, 1.0);
    finishRoughness = roughness;
    if (layered && uTexture.x > TEXTURE_STONE - 0.5 &&
        uTexture.x < TEXTURE_STONE + 0.5) {
      float stonePit = uFigure.w * strength *
          smoothstep(0.70, 0.88, valueNoise(q * vec2(0.07, 0.3) + 3.0));
      hints.xy += vec2(stonePit, 0.6 * stonePit);
    }
    if (uTexture.x > TEXTURE_METAL - 0.5 && uTexture.x < TEXTURE_METAL + 0.5) {
      specularTint = mix(specularTint, 1.0, strength);
      diffuseShare = mix(1.0, METAL_DIFFUSE, strength);
    }

    float age = uWear.x;
    if (age > 0.0) {
      float isMetal = uTexture.x > TEXTURE_METAL - 0.5 &&
              uTexture.x < TEXTURE_METAL + 0.5
          ? 1.0
          : 0.0;
      float nearEdge = smoothstep(14.0, 0.0, max(-box.x, 0.0));
      float stain = fbm(q * 0.016 + 91.0) + 0.25 * valueNoise(q * 0.09 + 5.0);
      if (isMetal > 0.5) {
        // Metal first dulls and darkens all over as it oxidises. Its patina
        // then blooms out of that, starting at the edges and spreading in
        // soft, speckled drifts with no hard outline.
        float oxide = smoothstep(0.0, 0.65, age);
        surfaceColor = mix(surfaceColor, surfaceColor * METAL_OXIDE,
                           oxide * (0.55 + 0.25 * valueNoise(q * 0.05 + 17.0)));
        float bloom = smoothstep(0.25, 1.0, age);
        float starts = mix(1.25, 0.2, bloom);
        float field = stain + 0.3 * nearEdge +
            0.12 * (valueNoise(q * 0.7 + 3.0) - 0.5);
        float patina = smoothstep(starts, starts + 0.6, field);
        float speckle = 0.7 + 0.3 * valueNoise(q * 1.4 + 29.0);
        surfaceColor =
            mix(surfaceColor, uPatinaColor, patina * speckle * AGE_STAIN);
        specularTint *= 1.0 - 0.7 * patina;
        roughness = clamp(roughness + age * 0.15 + patina * 0.35, 0.08, 1.0);
      } else {
        // Wood, stone and plastic mellow all over, with faint soft staining
        // that gathers a little towards the edges.
        float starts = mix(0.95, 0.38, age);
        float patches = smoothstep(starts, starts + 0.55, stain + 0.15 * nearEdge);
        float patina = max(patches * AGE_SOFT_STAIN, age * AGE_MELLOWING);
        surfaceColor = mix(surfaceColor, uPatinaColor, patina);
        roughness = clamp(roughness + age * AGE_ROUGHNESS, 0.08, 1.0);
      }
    }
    if (uWear.y + uWear.z > 0.0) {
      vec2 hollows;
      vec4 flaw = imperfections(uTexture.x, q, uWear.y, uWear.z,
                                max(-box.x, 0.0), layered, hollows);
      hints.xy = clamp(hints.xy + hollows, 0.0, 1.0);
      normal = normalize(normal + vec3(flaw.xy, 0.0));
      diffuseShare *= flaw.z;
      roughness = clamp(roughness + flaw.w, 0.08, 1.0);
    }
  }

  float mossCover = 0.0;
  if (relit) {
    vec4 body = bakedAt(coord, vec2(0.0, 0.0));
    vec4 fine = bakedAt(coord, vec2(1.0, 0.0));
    vec4 finish = bakedAt(coord, vec2(0.0, 1.0));
    vec4 hinted = bakedAt(coord, vec2(1.0, 1.0));
    vec2 stored = fine.xy * 2.0 - 1.0;
    vec2 lean = sign(stored) * stored * stored * BAKED_SLOPE;
    normal = normalize(vec3(shapeNormal.xy / shapeNormal.z + lean, 1.0));
    surfaceColor = body.rgb;
    roughness = fine.z;
    specularTint = finish.x;
    diffuseShare = 2.0 * finish.y;
    hints = vec4(hinted.x, hints.y, hinted.y, finish.z);
    mossCover = hinted.z;
  }

  if (layered) {
    if (!relit) hints.z = clamp(finishRoughness * 1.4 - 0.3, 0.0, 1.0);
    float textureScale = max(uTexture.y, 0.05);
    float heavy = uWear.z * uWear.z;
    float crackShare =
        uTexture.x > 0.5 ? fissuring(uTexture.x) * heavy : 0.0;
    float pull = min(length(uWorld.xy), 1.0);
    vec2 down = pull > 0.001 ? uWorld.xy / length(uWorld.xy) : vec2(0.0, 1.0);

    if (grown && !relit) {
      // Moss takes hold where the surface is damp and sheltered: in and
      // beside cracks, pits and chips, and along the edges. As it spreads
      // it creeps out from those places until it covers everything.
      float starts = mix(1.35, 0.12, uGrowth.x);
      float field = dampAt(p) + 0.7 * hints.y +
          0.18 * (valueNoise(p * 0.45 + 9.0) - 0.5);
      // Cushions are warped so they do not sit on a grid, and in places
      // they run together into a smooth carpet.
      vec2 warped = p + 9.0 * (vec2(valueNoise(p * 0.05 + 3.0),
                                    valueNoise(p * 0.05 + 91.0)) - 0.5);
      vec3 cushion = mossCushionAt(warped, 15.0);
      vec3 small = mossCushionAt(warped + 40.0, 6.0);
      vec3 sprig = mossCushionAt(p + 80.0, MOSS_SPRIG);
      float carpet = smoothstep(0.4, 0.7, valueNoise(p * 0.03 + 433.0));
      cushion = mix(cushion, vec3(0.0, 0.0, 0.8), 0.7 * carpet);
      float crown = 0.65 * cushion.z + 0.35 * small.z;
      // The pile is made of sprigs, which also fray the edge of the moss
      // into a scatter of them where it is thinning out.
      field += 0.22 * (crown - 0.5) + MOSS_FRAY * (sprig.z - 0.5);
      mossCover = smoothstep(starts, starts + 0.1, field) *
          smoothstep(0.0, 0.04, uGrowth.x);
      float depth = smoothstep(starts, starts + 0.5, field);
      float dampFringe = smoothstep(starts - 0.16, starts, field) *
          smoothstep(0.0, 0.04, uGrowth.x);
      surfaceColor *= 1.0 - 0.3 * dampFringe * (1.0 - mossCover);

      // Crowns catch the light and are yellow-green; the gaps between
      // cushions are deep and nearly black. Each sprig has a bright tip
      // and a dark foot, which gives the pile its velvet. Moss is young
      // and bright where it is still spreading and darker where it is
      // deep and old.
      float tip = sprig.z * sprig.z;
      float drift = valueNoise(p * 0.035 + 5.0);
      vec3 crownColor = mix(MOSS_BRIGHT, MOSS_SUNLIT, drift);
      crownColor = mix(MOSS_YOUNG, crownColor, smoothstep(0.0, 0.5, depth));
      crownColor = mix(crownColor, MOSS_DRY,
                       0.45 * smoothstep(0.55, 0.85, valueNoise(p * 0.02 + 900.0)));
      vec3 mossColor = mix(MOSS_DEEP, crownColor, crown * crown);
      mossColor *= (0.62 + 0.6 * tip) * (0.8 + 0.2 * depth);
      surfaceColor = mix(surfaceColor, mossColor, mossCover);
      vec2 pile = cushion.xy * 0.9 + small.xy * 0.45 + sprig.xy * 0.55;
      normal = normalize(mix(normal, shapeNormal, mossCover) +
                         vec3(pile * mossCover, 0.0));
      roughness = mix(roughness, 0.95, mossCover);
      specularTint = mix(specularTint, 0.0, mossCover);
      diffuseShare = mix(diffuseShare, 0.5 + 0.5 * crown, mossCover);
      hints.w = mossCover;

      if (uGrowth.y > 0.0) {
        float thatch;
        vec4 blade = grassAt(p, down, uGrowth.y, textureScale, crackShare,
                             heavy, thatch);
        surfaceColor *= 1.0 - 0.45 * thatch * (1.0 - blade.z);
        float bladeShade = floor(blade.w) / 8.0;
        float upBlade = fract(blade.w);
        vec3 tipColor =
            mix(GRASS_COOL, GRASS_TIP, smoothstep(0.0, 0.6, bladeShade));
        vec3 bladeColor =
            mix(GRASS_ROOT, tipColor, smoothstep(0.0, 0.75, upBlade));
        bladeColor = mix(bladeColor, GRASS_STRAW,
                         smoothstep(0.7, 1.0, bladeShade) *
                             (0.4 + 0.6 * upBlade));
        bladeColor *= 0.8 + 0.4 * bladeShade;
        surfaceColor = mix(surfaceColor, bladeColor, blade.z);
        normal = normalize(mix(normal, shapeNormal, blade.z) +
                           vec3(blade.xy * blade.z, 0.0));
        roughness = mix(roughness, 0.6, blade.z);
        specularTint = mix(specularTint, 0.0, blade.z);
        diffuseShare = mix(diffuseShare, 1.0, blade.z);
        hints.w = max(hints.w, blade.z);
      }

      if (uGrowth.z > 0.0) {
        float lushest = max(uGrowth.x, max(uGrowth.y, 0.6 * uGrowth.z));
        float flowerShadow;
        vec2 groundStarts = vec2(
            uGrowth.x > 0.04 ? starts : NO_GROWTH,
            uGrowth.y > 0.0 ? mix(1.3, 0.25, uGrowth.y) : NO_GROWTH);
        vec4 flower = flowerAt(p, uGrowth.z, mix(1.1, 0.3, lushest),
                               groundStarts, textureScale, crackShare, heavy,
                               flowerShadow);
        surfaceColor *= 1.0 - 0.4 * flowerShadow * (1.0 - flower.z);
        // No two flowers are quite one colour: some are paler.
        vec3 bloom = mix(uBloomColor, vec3(1.0),
                         0.3 * hash(floor(p / FLOWER_CELL) + 77.0));
        vec3 flowerColor = mix(bloom * 0.6, mix(bloom, vec3(1.0), 0.4),
                               clamp(flower.w, 0.0, 1.0));
        if (flower.w > FLOWER_LEAF_TONE - 0.5) {
          flowerColor = LEAF_COLOR * (0.5 + fract(flower.w));
        } else if (flower.w > FLOWER_HEART_TONE - 0.5) {
          flowerColor =
              FLOWER_HEART * (0.65 + 0.55 * valueNoise(p * 2.6 + 40.0));
        }
        surfaceColor = mix(surfaceColor, flowerColor, flower.z);
        normal = normalize(mix(normal, shapeNormal, flower.z) +
                           vec3(flower.xy * flower.z, 0.0));
        roughness = mix(roughness, 0.7, flower.z);
        specularTint = mix(specularTint, 0.0, flower.z);
        diffuseShare = mix(diffuseShare, 1.0, flower.z);
        hints.w = max(hints.w, flower.z);
      }
    }

    if (watered) {
      float dew = uWater.x;
      float rain = uWater.y;
      // A rough or porous finish soaks water up: fewer beads stand on it
      // and it darkens where it is wet.
      float porosity = hints.z;
      float beading = 1.0 - 0.5 * porosity;

      vec3 bead = beadsAt(p, 11.0, 0.85 * dew * beading, 0.0);
      vec3 largeBead = beadsAt(p, 27.0, 0.6 * dew * beading, 40.0);
      if (largeBead.z > bead.z) bead = largeBead;
      float trail = 0.0;
      vec2 trailLean = vec2(0.0);
      if (uStage.x > 0.5) {
        // The body beneath shapes the water on it: how rough or porous its
        // finish is and how bumpy its fine relief.
        vec2 fineLean =
            normal.xy / max(normal.z, 0.05) - shapeNormal.xy / shapeNormal.z;
        float bumpy = clamp(2.0 * length(fineLean), 0.0, 1.0);
        float grit = clamp(hints.z + 0.5 * bumpy, 0.0, 1.0);
        vec4 fallen = rainAt(p + halfSize, 0.08 + 0.14 * grit, trailLean);
        fallen.zw *= 1.0 - hints.w;
        if (fallen.z > bead.z) bead = fallen.xyz;
        // Water left behind a drop does not lie evenly, and what it lies
        // on decides how. It gathers in the hollows the layers beneath
        // have reported, their scratches, pits and cracks. On a rough or
        // porous finish it thins and breaks into patches, while on a slick
        // one it stays a clean streak. And its surface follows the fine
        // relief of the body beneath it.
        float patchy = 0.6 * valueNoise(p * 0.22 + 311.0) +
            0.4 * valueNoise(p * 0.7 + 97.0);
        float held = mix(0.75, patchy + 0.05, 0.35 + 0.65 * grit) +
            0.5 * hints.x;
        trail = fallen.w * smoothstep(0.22, 0.62, held);
        trailLean += ((vec2(valueNoise(p * 0.55 + 13.0),
                            valueNoise(p * 0.55 + 71.0)) -
                       0.5) *
                          (0.3 + 0.6 * grit) +
                      0.6 * fineLean) *
            trail;
      }

      // Water lies in the hollows: it fills grooves, pits and cracks level,
      // and they take more of it where a drop has just run past.
      float standing = clamp(rain + 0.5 * dew + 1.5 * trail, 0.0, 1.0);
      float pooled = clamp(1.5 * standing * hints.x, 0.0, 1.0);
      float sheet = 0.55 * rain * (0.4 + 0.6 * valueNoise(p * 0.03 + 55.0));
      float film = clamp(sheet + pooled + trail, 0.0, 1.0);
      float soaked = mix(porosity, 1.0, hints.w);
      float wet = 1.0 - 0.22 * (film - trail) * soaked - 0.06 * trail * soaked;
      surfaceColor *= wet;
      roughness =
          mix(roughness, 0.14, film * (1.0 - 0.6 * hints.w));
      normal = normalize(mix(normal, shapeNormal, 0.7 * pooled));

      // A bead is a lens, and its own surface is smooth whatever it sits
      // on. What lies beneath is seen through it shifted towards its
      // middle, so the grain or the speckle of the body shows bent inside
      // each drop. It gathers light onto its far side, shades a little on
      // its near side, and is picked out by a faint dark line where it
      // meets the body. It throws only a small glint.
      float cover = bead.z * (1.0 - 0.4 * mossCover);
      if (relit && cover > 0.01) {
        vec3 through =
            bakedAt(coord - bead.xy * WATER_REFRACTION, vec2(0.0)).rgb * wet;
        surfaceColor = mix(surfaceColor, through, cover);
      }
      float gathered = clamp(dot(bead.xy, -uLight.xy) * 2.2, -1.0, 1.0);
      surfaceColor *= mix(1.0, 1.0 + 0.3 * max(gathered, 0.0) +
                                   0.2 * min(gathered, 0.0),
                          cover);
      surfaceColor *= 1.0 - 0.7 * cover * (1.0 - cover);
      vec2 towards = uLight.xy / max(length(uLight.xy), 0.001);
      glint = 0.3 * cover * smoothstep(0.55, 0.85, dot(bead.xy, towards));

      // A trail is water too: a low ridge that catches the light along the
      // edge turned to it and glows faintly along the other, so it reads
      // as wet and not as a stain. It lightens the body in proportion to
      // the body's own colour and adds only a thin line of light of its
      // own, so it does not show as a pale streak across a dark body.
      float trailed = trail * (1.0 - cover);
      surfaceColor *=
          1.0 + 0.25 * trailed * max(dot(trailLean, -towards), 0.0);
      float body = dot(surfaceColor * surfaceColor, LUMA);
      glint += trailed * mix(0.1, 0.3, smoothstep(0.02, 0.4, body)) *
          smoothstep(0.3, 0.6, dot(trailLean, towards));
      normal = normalize(mix(
          normal, normalize(shapeNormal + vec3(trailLean * 0.7, 0.0)),
          trailed));
      roughness = mix(roughness, WATER_ROUGHNESS, 0.3 * trailed);
      normal = normalize(mix(
          normal, normalize(shapeNormal + vec3(bead.xy * 0.8, 0.0)), cover));
      roughness = mix(roughness, WATER_ROUGHNESS, cover);
      specularTint = mix(specularTint, 0.0, cover);
      water = max(film, cover);
    }
  }

  if (baking) {
    vec2 lean = normal.xy / max(normal.z, 0.05) - shapeNormal.xy / shapeNormal.z;
    fragColor = bakedTile(tile, surfaceColor, lean, roughness, specularTint,
                          diffuseShare, hints, mossCover);
    return;
  }

  // A fire round the body scorches it from the edge inwards. What burns
  // readily chars black, and the char cracks into embers that glow and
  // fade; what does not only darkens with soot.
  float embers = 0.0;
  bool burning = overlay < 0.5 && uEffect.x > EFFECT_FLAME - 0.5 &&
      uEffect.x < EFFECT_FLAME + 0.5;
  if (burning && uScorch.x * uScorch.y > 0.0) {
    float depth = max(-box.x, 0.0);
    float reachIn = uScorch.y * (0.4 + 0.6 * uScorch.x);
    if (depth < reachIn * 1.6) {
      float ragged = fbm(p * 0.035 + 300.0);
      float burn = uScorch.x * uEffect.y *
          (1.0 - smoothstep(0.0, reachIn * (0.35 + 1.25 * ragged), depth));
      float charred = clamp(1.3 * burn, 0.0, 1.0);
      surfaceColor = mix(surfaceColor, CHAR_COLOR, 0.92 * charred);
      roughness = mix(roughness, 0.92, charred);
      specularTint *= 1.0 - charred;
      if (uScorch.z > 0.0) {
        vec2 crazed = p + 14.0 * (vec2(ragged, fbm(p * 0.05 + 510.0)) - 0.5);
        float crack = 1.0 - abs(2.0 * fbm(crazed * 0.05 + 77.0) - 1.0);
        // Each ember breathes where it lies, brightening and dying back at
        // a pace and from a moment of its own, so no pattern is seen to
        // travel across the char.
        float moment = valueNoise(p * 0.045 + 40.0) * TAU * 3.0;
        float pace = 0.35 + 0.6 * valueNoise(p * 0.03 + 200.0);
        float breath = 0.5 + 0.5 * sin(uWater.z * pace + moment);
        // Embers need the heat of the flame, so they thin out and dim with
        // distance from the burning edge and are gone well before the char
        // is.
        float heat = 1.0 - smoothstep(0.0, reachIn * EMBER_REACH, depth);
        float sparse = mix(1.0, mix(0.995, 0.9, uScorch.z), heat);
        embers = uScorch.x * uScorch.z * heat * heat *
            smoothstep(sparse, 1.0, crack) * smoothstep(0.35, 0.8, burn) * (0.15 + 0.85 * breath * breath);
      }
    }
  }

  vec3 light = uLight;
  vec3 halfway = normalize(light + vec3(0.0, 0.0, 1.0));
  float nDotL = max(dot(normal, light), 0.0);
  float nDotH = max(dot(normal, halfway), 0.0);
  float lDotH = max(dot(light, halfway), 0.0);
  float nDotV = max(normal.z, 0.0);

  vec3 fill = uFillColor * AMBIENT;
  vec3 key = uKeyColor * (1.0 - AMBIENT);
  vec3 flatLight = fill + key;
  vec3 reference = mix(flatLight, vec3(dot(flatLight, LUMA)), LIGHT_TINT_REACH);
  // Leaves, petals and moss are thin and let light into them. It wraps
  // round onto the faces turned away from it, so they are never in hard
  // shade, and what passes right through comes out in their own colour.
  float organic = hints.w;
  float facing = dot(normal, light);
  float wrapped = max(facing + SUBSURFACE_WRAP, 0.0) / (1.0 + SUBSURFACE_WRAP);
  float flatWrapped =
      (uFlatIncidence + SUBSURFACE_WRAP) / (1.0 + SUBSURFACE_WRAP);
  float incidence = mix(nDotL / uFlatIncidence, wrapped / flatWrapped, organic);
  float passing =
      max(dot(vec3(-normal.xy, normal.z), light) - max(facing, 0.0), 0.0);
  vec3 diffuse = (fill + key * incidence) / reference;

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

  vec3 baseAlbedo = surfaceColor * surfaceColor;
  vec3 albedo = baseAlbedo * diffuseShare;
  vec3 hue = baseAlbedo / max(max(baseAlbedo.r, baseAlbedo.g),
                              max(baseAlbedo.b, 0.001));
  vec3 scattered = organic * SUBSURFACE_GLOW * passing *
      mix(baseAlbedo, hue, SUBSURFACE_SATURATION) * key / reference;
  vec3 f0 = mix(vec3(DIELECTRIC_F0), baseAlbedo, specularTint);
  vec3 glare = (f0 * specular + vec3(rim)) * uKeyColor;
  vec3 highlights = glare / (1.0 + glare) + 0.55 * glint * uKeyColor;

  float dither =
      (interleavedGradientNoise(FlutterFragCoord().xy * pixelRatio) - 0.5) *
      DITHER;

  if (hinting) {
    vec3 hint = vec3(0.3 * hints.y) + vec3(hints.x, hints.w, water);
    fragColor = vec4(hint, 1.0) * uColor.a * coverage;
    return;
  }

  if (overlay > 0.5) {
    float brightness = dot(diffuse, LUMA);
    float shade = clamp((1.0 - brightness) * OVERLAY_SHADE, 0.0, 1.0);
    float lift = clamp((brightness - 1.0) * OVERLAY_LIFT, 0.0, 1.0);
    vec3 glint = sqrt(OVERLAY_BACKDROP + highlights) - sqrt(OVERLAY_BACKDROP);
    fragColor = vec4(glint + vec3(lift) + dither, shade + lift) * coverage;
    return;
  }

  float effect = overlay < 0.5 ? uEffect.x : 0.0;
  float time = uWater.z;
  if (effect > EFFECT_NEON - 0.5 && effect < EFFECT_NEON + 0.5) {
    fragColor =
        neon(box.x, bevel, halfSize, time, highlights) * uColor.a + dither;
    return;
  }

  vec3 lit = sqrt(albedo * diffuse + scattered + highlights) + dither;
  vec4 surface = vec4(lit, 1.0) * uColor.a * coverage;
  float shadowStrength = SHADOW_STRENGTH;

  if (overlay < 0.5 && uVessel.x > VESSEL_GLASS - 0.5) {
    bool holding = uVessel.x > VESSEL_LIQUID - 0.5;
    // Glass is thin in the middle and thick where its edge turns away, so
    // it shows most of its colour at the rim. Light passing through gathers
    // into a bright crescent on the side away from the light.
    vec3 tint = holding ? vec3(0.87, 0.94, 0.95) : uVessel.yzw;
    float solidity = uEffectShape.y;
    float thick = shoulder * shoulder;
    float glassAlpha =
        mix(0.06 + 0.5 * solidity, 0.35 + 0.6 * solidity, thick);
    float crescent = max(dot(box.yz, -light.xy), 0.0) * shoulder *
        (1.0 - shoulder) * 4.0;
    vec3 glassColor =
        sqrt(tint * tint * (diffuse + crescent * 0.8)) * glassAlpha;
    float alpha = glassAlpha;
    if (holding) {
      vec4 filled = liquid(p, halfSize, box.x, time);
      vec3 liquidLit = sqrt(filled.rgb * (diffuse * 0.75 + 0.25 + crescent));
      glassColor = mix(glassColor, liquidLit * 0.94, filled.a);
      alpha = mix(alpha, 0.94, filled.a);
    }
    // A vessel carries a long soft highlight just inside its lit edge.
    float inward = clamp(-box.x / min(halfSize.x, halfSize.y), 0.0, 1.0);
    float streak = smoothstep(0.1, 0.19, inward) *
        (1.0 - smoothstep(0.22, 0.36, inward)) *
        max(dot(box.yz, light.xy), 0.0);
    float shine = dot(highlights, LUMA) + 0.3 * streak;
    surface = vec4(glassColor + sqrt(highlights) + 0.3 * streak + dither,
                   min(alpha + shine, 1.0)) *
        uColor.a * coverage;
    shadowStrength *= 0.3 + 0.7 * alpha;
  }

  vec4 fire = vec4(0.0);
  if (effect > EFFECT_FLAME - 0.5 && effect < EFFECT_FLAME + 0.5) {
    // Flames only stand outside the body and close to it, so the work of
    // drawing them is skipped everywhere else.
    float thrown = firelight(p, vec2(-uEffectDown.y, uEffectDown.x), time);
    float flameReach = max(uEffectShape.x * uEffect.y, 1.0) * 1.5;
    if (box.x > -4.0 && box.x < flameReach) {
      fire = flames(p, halfSize, box.x, time, thrown) * uColor.a;
    }
    surface.rgb += sqrt(EMBER_COLOR) * embers * surface.a;
    // Firelight falls on the body it surrounds: strongest at the rim next
    // to the flames, reaching in about as far as they stand tall, over a
    // faint warm wash across the whole face.
    float lit = clamp(uEffectShape.x * uEffect.y * 0.5, 14.0, 36.0);
    float rimLit = 1.0 - smoothstep(0.0, lit, max(-box.x, 0.0));
    surface.rgb += sqrt(uEffectColor * uEffectColor) * thrown *
        (0.06 + 0.6 * rimLit * rimLit) * surface.a;
  }

  vec2 shadowOffset = -light.xy / max(light.z, 0.3) * elevation;
  float softness = elevation * 1.2 + 1.0;
  float shadowDistance = roundedBox(p - shadowOffset, halfSize).x;
  float shadow = shadowStrength * uColor.a * step(0.001, elevation) *
      (1.0 - smoothstep(-softness, softness, shadowDistance));

  fragColor = surface + vec4(0.0, 0.0, 0.0, shadow) * (1.0 - surface.a) +
      fire * (1.0 - 0.85 * surface.a);
}
