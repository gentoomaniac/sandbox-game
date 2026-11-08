shader_type canvas_item;
#include "res://game/scenes/hash.gdshaderinc"
#include "res://game/scenes/art_scale.gdshaderinc"
// Lily pads drifting a pixel back and forth and bobbing, slowly, each tile in its own rhythm
// (hashed from where it is). The wind (`drift`, set by AmbientMotion) widens the drift. Set on
// the decoration tiles of water, in an atlas without padding.

// A tile in art pixels, the 16 px art's.
const float TILE = 16.0;
// Art pixels the pads drift to either side and bob up and down, before rounding.
uniform float drift = 0.6;
const float BOB = 0.6;

varying vec2 world_position;
varying vec4 modulate;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

void fragment() {
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE / art_scale);
	vec2 local = mod(texel, TILE);
	float phase = hash(floor(world_position / art_scale) - local) * TAU;
	vec2 offset = vec2(
		drift * sin(TIME * 0.15 * TAU + phase),
		BOB * sin(TIME * 0.23 * TAU + phase * 1.9)
	);
	offset = sign(offset) * floor(abs(offset) + 0.5);
	vec2 source = local - offset;
	if (any(lessThan(source, vec2(0.0))) || any(greaterThanEqual(source, vec2(TILE)))) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, ((texel - offset) * art_scale + 0.5) * TEXTURE_PIXEL_SIZE) * modulate;
	}
}
