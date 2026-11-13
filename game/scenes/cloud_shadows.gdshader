shader_type canvas_item;
#include "res://game/scenes/hash.gdshaderinc"
// Cloud shadows over the world viewport: soft dark patches that stick to the world and drift
// with the wind (no cloud is drawn). Each pixel looks up smooth noise at its world position
// minus how far the shadows have drifted, and is dark where the noise is above a threshold that
// falls with the cover, so more cover gives more of the ground in shadow. Every number that sets
// the look comes from data/lighting.cfg [cloud_shadows], through WeatherView.

uniform vec2 view_size;
// The world position of the middle of the view, in whole pixels.
uniform vec2 camera;
// How far the shadows have drifted, in pixels.
uniform vec2 drift;
// The cloud cover shown now (0 to 1).
uniform float cover : hint_range(0.0, 1.0) = 0.0;
// The opacity of a shadow's darkest part, and the width of a patch (pixels).
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float size = 180.0;
// How much of the ground is in shadow at full cover, and how wide the soft edge is (noise units).
uniform float coverage : hint_range(0.0, 1.0) = 0.9;
uniform float softness : hint_range(0.01, 1.0) = 0.2;

// palette: tools/art/palette.py (not guarded by a test)
const vec3 SHADOW_COLOR = vec3(0.04, 0.07, 0.16);
// Noise values pile up around the middle; this stretches them over the whole 0 to 1 so that the
// share of the ground in shadow is about the threshold's share.
const float CONTRAST = 2.2;
// How far (in patches) the warp pushes the noise at most.
const float WARP = 0.9;

vec2 gradient(vec2 corner) {
	float angle = hash(corner) * TAU;
	return vec2(cos(angle), sin(angle));
}

// Smooth noise around 0.5: a unit gradient with a random direction on each corner of the grid, so
// no straight crease follows the grid the way it does with a random value per corner.
float gradient_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 g00 = gradient(cell);
	vec2 g10 = gradient(cell + vec2(1.0, 0.0));
	vec2 g01 = gradient(cell + vec2(0.0, 1.0));
	vec2 g11 = gradient(cell + vec2(1.0, 1.0));
	float along = mix(
		mix(dot(g00, f), dot(g10, f - vec2(1.0, 0.0)), u.x),
		mix(dot(g01, f - vec2(0.0, 1.0)), dot(g11, f - vec2(1.0, 1.0)), u.x),
		u.y);
	return 0.5 + along * 0.7;
}

void fragment() {
	vec2 p = floor(UV * view_size);
	vec2 world = floor(p + camera - view_size * 0.5) - drift;
	vec2 at = world / size;
	// A little domain warp bends the patches into rounder shapes.
	at += WARP * vec2(gradient_noise(at * 0.8 + 19.7), gradient_noise(at * 0.8 + 41.3)) - WARP * 0.5;
	float noise = 0.55 * gradient_noise(at) + 0.3 * gradient_noise(at * 2.0 + 7.1) + 0.15 * gradient_noise(at * 4.0 + 3.3);
	noise = clamp(0.5 + (noise - 0.5) * CONTRAST, 0.0, 1.0);
	float threshold = 1.0 - cover * coverage;
	float shadow = smoothstep(threshold, threshold + softness, noise);
	COLOR = vec4(SHADOW_COLOR, shadow * strength);
}
