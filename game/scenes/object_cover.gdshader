shader_type canvas_item;
#include "res://game/scenes/art_scale.gdshaderinc"
#include "res://game/scenes/ground_cover.gdshaderinc"
#include "res://game/scenes/object_cover.gdshaderinc"
// The objects that stand still (stones, fences, stumps, stations) with the frost and the snow of
// the weather over them (see object_cover.gdshaderinc). The layer of the objects has it, in an
// atlas without padding made of cells of `cell_size` (in art pixels, see GroundLook); the plants
// that sway have the same in their own shader.

uniform vec2 cell_size = vec2(96.0, 160.0);

varying vec2 world_position;
varying vec4 modulate;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

void fragment() {
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE / art_scale);
	vec2 origin = floor(world_position / art_scale) - mod(texel, cell_size);
	vec2 anchor = cell_anchor(origin, cell_size, art_scale);
	COLOR = object_covered(texture(TEXTURE, UV), UV, anchor) * modulate;
}
