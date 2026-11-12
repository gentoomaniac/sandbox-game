shader_type canvas_item;
#include "res://game/scenes/art_scale.gdshaderinc"
#include "res://game/scenes/ground_look.gdshaderinc"
// The land of the terrain and the decorations that stand still: the grass and the ground in the
// colour of the time of year with the leaves, frost and snow of the weather over it (see
// ground_look.gdshaderinc). Made by GroundLook.

varying vec2 world_position;
varying vec4 modulate;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

void fragment() {
	float drawn = texture(TEXTURE, UV).a;
	COLOR = drawn == 0.0 ? vec4(0.0) : ground_pixel(UV, drawn, world_position, art_scale) * modulate;
}
