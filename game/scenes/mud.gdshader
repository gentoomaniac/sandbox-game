shader_type canvas_item;
#include "res://game/scenes/hash.gdshaderinc"
#include "res://game/scenes/water_surface.gdshaderinc"
// The tide on the tidal mud, a look only: the sea rises over the flats and falls again (`tide`,
// 0 at low water to 1 at high water, set by AmbientMotion from Tide). The mud has a gentle relief
// of its own, a smooth noise anchored to the world: as the water rises it first fills the ripple
// troughs and the hollows, then spreads into pools that join, until at high water it covers the
// flats; a line of light water marks its edge. Under water the mud moves like the sea (see
// water_surface.gdshaderinc). On the mud layer of the terrain.

uniform float tide : hint_range(0.0, 1.0) = 0.0;

// palette: tools/art/palette.py (tests/test_shader_palette.gd guards it)
const vec3 MUD_DARK = vec3(0.310, 0.267, 0.212);
// The water's level at low and at high water, on the relief's scale (0 to 1): at low water only
// the deepest troughs hold a little, at high water all of it is under.
const float LOW_WATER = 0.04;
const float HIGH_WATER = 1.06;
// How much lower the dark troughs and banks lie than the mud around them.
const float TROUGH_DEPTH = 0.07;
// How far below the water's edge (on the relief's scale) its light line reaches.
const float SHORE = 0.025;
// The relief: broad swells and smaller hollows, in pixels across.
const float SWELL_SIZE = 70.0;
const float HOLLOW_SIZE = 23.0;

varying vec2 world_position;
varying vec4 modulate;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

// A value from 0 to 1 for a corner of the relief's grid, from whole numbers: the float hash of
// hash.gdshaderinc can come out different for the same corner reached from two cells (a rounding
// in its sine), which tore the relief apart along their edges.
float corner_value(ivec2 corner, uint layer) {
	uint h = uint(corner.x) * 73856093u ^ uint(corner.y) * 19349663u ^ layer * 83492791u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h & 65535u) / 65535.0;
}

// Smooth noise from 0 to 1, with a value per corner of a grid of `size` pixels.
float value_noise(vec2 p, float size, uint layer) {
	ivec2 cell = ivec2(floor(p / size));
	vec2 f = smoothstep(0.0, 1.0, fract(p / size));
	float a = corner_value(cell, layer);
	float b = corner_value(cell + ivec2(1, 0), layer);
	float c = corner_value(cell + ivec2(0, 1), layer);
	float d = corner_value(cell + ivec2(1, 1), layer);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a > 0.0) {
		vec2 p = floor(world_position);
		float height = 0.65 * value_noise(p, SWELL_SIZE, 1u) + 0.35 * value_noise(p, HOLLOW_SIZE, 2u);
		if (distance(base.rgb, MUD_DARK) < 0.02) {
			height -= TROUGH_DEPTH;
		}
		float level = mix(LOW_WATER, HIGH_WATER, tide);
		if (height < level) {
			vec3 water = height > level - SHORE ? WATER_LIGHT : water_surface(p);
			COLOR.rgb = water * modulate.rgb;
		}
	}
}
