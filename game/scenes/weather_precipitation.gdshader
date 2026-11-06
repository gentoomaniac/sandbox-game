shader_type canvas_item;
#include "res://game/scenes/hash.gdshaderinc"
// Rain, snow, wind streaks and blowing leaves over the whole world viewport, drawn per art
// pixel: every effect is made of whole pixels (one pixel wide streaks, 1 or 2 pixel flakes),
// so it stays crisp on the pixel grid. Nothing is stored: each pixel works out whether it is
// part of a drop, flake, streak or leaf from its position and the distances (`*_scroll`) the
// effects have moved so far, which WeatherView accumulates from the wind. Positions are in
// world pixels (through `camera`), so the effects stay in place when the player walks.

uniform vec2 view_size;
// Where the camera looks, in world pixels (rounded to whole pixels).
uniform vec2 camera;
// The day tint, so that the effects darken at night like the world.
uniform vec4 tint : source_color = vec4(1.0);
uniform float time;

uniform float rain : hint_range(0.0, 1.0) = 0.0;
// How far the rain has fallen, in pixels, and how many pixels a drop moves sideways per
// pixel it falls.
uniform float rain_fall = 0.0;
uniform float rain_slant = 0.0;

uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform vec2 snow_scroll = vec2(0.0);

uniform float wind : hint_range(0.0, 1.0) = 0.0;
uniform vec2 wind_scroll = vec2(0.0);

// palette: tools/art/palette.py (not guarded by a test)
const vec3 RAIN_COLOR = vec3(0.66, 0.78, 0.95);
const vec3 SNOW_COLOR = vec3(0.96, 0.98, 1.0);
const vec3 STREAK_COLOR = vec3(0.92, 0.95, 1.0);

// A layer of rain: columns of a sheared grid hold a stream of drops each. Returns the alpha.
float rain_layer(vec2 p, float layer, float density, float drop_length, float speed, float period) {
	float column = floor(p.x - rain_slant * p.y);
	vec4 h = hash4(vec2(column, 0.0), layer);
	if (h.x > density) {
		return 0.0;
	}
	float along = mod(p.y - rain_fall * speed * (0.85 + 0.3 * h.y) + h.z * 997.0, period * (0.7 + 0.6 * h.y));
	if (along >= drop_length) {
		return 0.0;
	}
	// The head of the drop is the brightest.
	return 0.35 + 0.5 * along / drop_length;
}

// A layer of snow: one flake in some cells of a grid that moves with the snow.
float snow_layer(vec2 p, float layer, float cell_size, float flake_size, float density, float scale) {
	vec2 q = p - snow_scroll * scale;
	vec2 cell = floor(q / cell_size);
	vec4 h = hash4(cell, layer);
	if (h.w > density) {
		return 0.0;
	}
	float sway = sin(time * (0.8 + h.z) + h.z * 40.0) * 2.0;
	vec2 flake = floor(vec2(h.x * (cell_size - 6.0) + 3.0 + sway, h.y * (cell_size - flake_size)));
	vec2 local = floor(q - cell * cell_size) - flake;
	if (local.x < 0.0 || local.y < 0.0 || local.x >= flake_size || local.y >= flake_size) {
		return 0.0;
	}
	return 0.9;
}

// Thin streaks of air, a pixel high and faint at both ends.
float wind_streaks(vec2 p) {
	vec2 cell_size = vec2(140.0, 36.0);
	vec2 q = p - wind_scroll;
	vec2 cell = floor(q / cell_size);
	vec4 h = hash4(cell, 7.0);
	if (h.w > wind * 1.2) {
		return 0.0;
	}
	float streak_length = 24.0 + h.z * 40.0;
	vec2 start = floor(vec2(h.x * (cell_size.x - streak_length), 4.0 + h.y * (cell_size.y - 8.0)));
	vec2 local = floor(q - cell * cell_size) - start;
	float slope = (h.z - 0.5) * 0.2;
	if (local.x < 0.0 || local.x >= streak_length || local.y != floor(local.x * slope)) {
		return 0.0;
	}
	float edge = sin(3.14159 * local.x / streak_length);
	return edge > 0.35 ? (edge > 0.75 ? 0.6 : 0.3) : 0.0;
}

// A leaf: two pixels that bob as the wind carries them.
vec4 leaf(vec2 p) {
	vec2 cell_size = vec2(110.0, 70.0);
	vec2 q = p - wind_scroll * 1.15;
	vec2 cell = floor(q / cell_size);
	vec4 h = hash4(cell, 11.0);
	if (h.w > wind * 0.5) {
		return vec4(0.0);
	}
	float bob = sin(time * 3.0 + h.z * 40.0) * 4.0;
	vec2 pos = floor(vec2(h.x * (cell_size.x - 4.0), 8.0 + h.y * (cell_size.y - 16.0) + bob));
	vec2 local = floor(q - cell * cell_size) - pos;
	// A leaf is wider than tall, and alternates between a wide and a narrow pose.
	float height = 1.0;
	float width = mod(floor(time * 4.0 + h.z * 9.0), 2.0) == 0.0 ? 3.0 : 2.0;
	if (local.x < 0.0 || local.y < 0.0 || local.x >= width || local.y >= height) {
		return vec4(0.0);
	}
	vec3 leaf_color = h.z < 0.4 ? vec3(0.82, 0.46, 0.14) : (h.z < 0.75 ? vec3(0.56, 0.34, 0.14) : vec3(0.52, 0.62, 0.20));
	return vec4(leaf_color, 1.0);
}

void fragment() {
	vec2 p = floor(UV * view_size) + camera - floor(view_size * 0.5);
	vec4 result = vec4(0.0);

	if (rain > 0.0) {
		float a = 0.0;
		a = max(a, rain_layer(p, 1.0, 0.07 * rain, 5.0, 1.0, 46.0));
		a = max(a, rain_layer(p, 2.0, 0.08 * rain, 7.0, 1.3, 60.0));
		a = max(a, rain_layer(p, 3.0, 0.055 * rain, 9.0, 1.6, 80.0));
		result = vec4(RAIN_COLOR, a);
	}
	if (snow > 0.0) {
		float a = 0.0;
		a = max(a, snow_layer(p, 1.0, 11.0, 1.0, 0.55 * snow, 0.5));
		a = max(a, snow_layer(p, 2.0, 15.0, 2.0, 0.45 * snow, 0.8));
		a = max(a, snow_layer(p, 3.0, 22.0, 2.0, 0.4 * snow, 1.0));
		if (a > result.a) {
			result = vec4(SNOW_COLOR, a);
		}
	}
	if (wind > 0.0) {
		float a = wind_streaks(p);
		if (a > result.a) {
			result = vec4(STREAK_COLOR, a);
		}
		vec4 l = leaf(p);
		if (l.a > 0.0) {
			result = l;
		}
	}
	COLOR = vec4(result.rgb * tint.rgb, result.a);
}
