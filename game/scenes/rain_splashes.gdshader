shader_type canvas_item;
#include "res://game/scenes/hash.gdshaderinc"
#include "res://game/scenes/art_scale.gdshaderinc"
// Raindrops splashing on the ground: a world-anchored grid where each cell may have a splash
// in each short cycle (with the chance `chance`, set by AmbientMotion from the rain), at a
// spot of its own every time: a pixel where the drop lands, then two flying out to the sides,
// then two farther out and fainter. Nothing is stored; each pixel works it out from its world
// position and the time. Drawn under the objects and the player (see RainSplashes).

uniform float chance : hint_range(0.0, 1.0) = 0.0;

// In art pixels, as everything below.
const vec2 CELL = vec2(12.0, 10.0);
const float CYCLE_SECONDS = 0.6;
// palette: tools/art/palette.py (not guarded by a test)
const vec3 SPLASH_COLOR = vec3(0.72, 0.82, 0.96);

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = floor(world_position / art_scale);
	vec2 cell = floor(p / CELL);
	// Cells run out of step, so splashes don't come in waves.
	float offset = hash(cell);
	float cycle = floor(TIME / CYCLE_SECONDS + offset);
	float age = fract(TIME / CYCLE_SECONDS + offset);
	vec2 seed = cell + cycle * vec2(0.37, 0.91);
	float alpha = 0.0;
	// A splash lasts the first third of its cycle.
	if (hash(seed) < chance && age < 0.33) {
		vec2 spot = floor(vec2(2.0 + hash(seed + 1.3) * (CELL.x - 5.0), 1.0 + hash(seed + 2.9) * (CELL.y - 2.0)));
		vec2 d = p - cell * CELL - spot;
		float frame = floor(age / 0.11);
		if (frame == 0.0 && d == vec2(0.0)) {
			alpha = 0.8;
		} else if (frame == 1.0 && d.y == -1.0 && abs(d.x) == 1.0) {
			alpha = 0.65;
		} else if (frame == 2.0 && d.y == -1.0 && abs(d.x) == 2.0) {
			alpha = 0.4;
		}
	}
	COLOR = vec4(SPLASH_COLOR, alpha);
}
