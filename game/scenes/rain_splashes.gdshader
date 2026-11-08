shader_type canvas_item;
#include "res://game/scenes/hash.gdshaderinc"
// Raindrops splashing on the ground: a world-anchored grid where each cell may have a splash
// in each short cycle (with the chance `chance`, set by AmbientMotion from the rain), at a
// spot of its own every time: the drop lands, a little crown of droplets flies up and out to
// the sides, then they fall back farther out and fainter, around a ring where it landed. In the
// world's pixels, as the art at 32 px per tile. Nothing is stored; each pixel works it out from
// its world position and the time. Drawn under the objects and the player (see RainSplashes).

uniform float chance : hint_range(0.0, 1.0) = 0.0;

// In pixels, as everything below.
const vec2 CELL = vec2(24.0, 20.0);
const float CYCLE_SECONDS = 0.6;
// palette: tools/art/palette.py (not guarded by a test)
const vec3 SPLASH_COLOR = vec3(0.72, 0.82, 0.96);

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = floor(world_position);
	vec2 cell = floor(p / CELL);
	// Cells run out of step, so splashes don't come in waves.
	float offset = hash(cell);
	float cycle = floor(TIME / CYCLE_SECONDS + offset);
	float age = fract(TIME / CYCLE_SECONDS + offset);
	vec2 seed = cell + cycle * vec2(0.37, 0.91);
	float alpha = 0.0;
	// A splash lasts the first third of its cycle.
	if (hash(seed) < chance && age < 0.33) {
		vec2 spot = floor(vec2(5.0 + hash(seed + 1.3) * (CELL.x - 11.0), 3.0 + hash(seed + 2.9) * (CELL.y - 5.0)));
		vec2 d = p - cell * CELL - spot;
		float side = abs(d.x);
		float frame = floor(age / 0.11);
		if (frame == 0.0 && d.x == 0.0 && (d.y == 0.0 || d.y == -1.0)) {
			alpha = d.y == 0.0 ? 0.8 : 0.5;
		} else if (frame == 1.0 && ((d.y == -1.0 && side == 1.0) || (d.y == -2.0 && side == 2.0))) {
			alpha = 0.7;
		} else if (frame == 1.0 && d == vec2(0.0)) {
			alpha = 0.4;
		} else if (frame == 2.0 && ((d.y == -1.0 && side == 3.0) || (d.y == 0.0 && side == 4.0))) {
			alpha = 0.45;
		} else if (frame == 2.0 && d.y == 0.0 && (side == 1.0 || side == 2.0)) {
			alpha = 0.25;
		}
	}
	COLOR = vec4(SPLASH_COLOR, alpha);
}
