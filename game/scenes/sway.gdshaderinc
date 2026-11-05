// The wind's sway, shared by the shaders of swaying plants (object_sway, decoration_sway).
// AmbientMotion sets the wind every frame; the swing itself runs on TIME. Every plant swings
// with its own phase, hashed from where its cell is in the world, so it never changes.

// How far the top of a plant swings to either side, how far it leans downwind (signed, + is
// right), both in pixels at full bend, and how much the gusts add (0 to 1).
uniform float sway = 0.0;
uniform float lean = 0.0;
uniform float gust = 0.0;
// Where the wind blows to, the way the gusts travel.
uniform vec2 wind_direction = vec2(1.0, 0.0);
// Swings per second: small plants swing faster than trees.
uniform float frequency = 0.5;

// Gusts are fronts that sweep downwind across the world this far apart, at this speed
// (pixels and pixels per second).
const float GUST_SPACING = 360.0;
const float GUST_SPEED = 90.0;

varying vec2 world_position;
varying vec4 modulate;

float sway_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// How far the top of a plant whose cell has its top left at `origin` (world pixels) is moved
// now, in pixels, not yet rounded.
float sway_at(vec2 origin) {
	float phase = sway_hash(origin) * TAU;
	// Neighbours a few tiles apart meet a front at slightly different times.
	float front = (dot(origin, wind_direction) - TIME * GUST_SPEED) / GUST_SPACING
		+ sway_hash(floor(origin / 64.0)) * 0.25;
	float in_gust = pow(0.5 + 0.5 * sin(TAU * front), 6.0) * gust;
	float swing = sin(TIME * frequency * TAU + phase)
		+ 0.3 * sin(TIME * frequency * 2.3 * TAU + phase * 1.7);
	return (lean * (1.0 + 1.5 * in_gust) + sway * (1.0 + in_gust) * swing / 1.3);
}

// Rounds to the nearest whole pixel, halves away from zero (GLSL's round leaves them open).
float whole_pixels(float x) {
	return sign(x) * floor(abs(x) + 0.5);
}
