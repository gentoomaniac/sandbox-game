shader_type canvas_item;
#include "res://game/scenes/art_scale.gdshaderinc"
// Fog over the world viewport: a veil that sticks to the world, drifts slowly and thickens and
// thins over wide, soft patches. Its opacity is cut into a few levels with an ordered dither
// (Bayer 4x4) between them, so it is made of whole art pixels and the level edges don't show
// as bands. Light fog is a thin, patchy veil; the denser it gets the more evenly it dims
// everything.

uniform vec2 view_size;
// The world position of the middle of the view, in whole art pixels.
uniform vec2 camera;
// How far the fog has drifted, in art pixels.
uniform vec2 drift;
uniform float fog : hint_range(0.0, 1.0) = 0.0;
// The day tint, so that the fog darkens at night like the world.
uniform vec4 tint : source_color = vec4(1.0);

// palette: tools/art/palette.py (not guarded by a test)
const vec3 FOG_COLOR = vec3(0.84, 0.87, 0.91);
// The opacity of the thickest fog, and the number of levels it is dithered between.
const float MAX_OPACITY = 0.7;
const float LEVELS = 4.0;
// How much of the patchiness dense fog loses: at full intensity this share of it is gone.
const float EVENING_OUT = 0.65;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 p = floor(UV * view_size);
	vec2 world = floor((p + camera - view_size * 0.5) / art_scale) - drift;
	// Wide, gentle patches: warped sine waves a hundred pixels or more across.
	float bank = sin(world.x / 170.0 + 1.3 * sin(world.y / 130.0));
	float stripe = sin(world.y / 110.0 + 1.1 * sin(world.x / 90.0 + 2.0));
	float patch = 0.5 + 0.5 * (0.6 * bank + 0.4 * stripe);
	float thickness = pow(fog, 0.75);
	float density = thickness * mix(0.3 + 0.7 * patch, 1.0, EVENING_OUT * fog);
	float level = density * LEVELS;
	ivec2 cell = ivec2(mod(floor(p / art_scale), 4.0));
	float threshold = (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0;
	float alpha = (floor(level) + step(threshold, fract(level))) / LEVELS * MAX_OPACITY;
	COLOR = vec4(FOG_COLOR * tint.rgb, alpha);
}
