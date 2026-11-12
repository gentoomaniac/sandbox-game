shader_type canvas_item;
#include "res://game/scenes/art_scale.gdshaderinc"
#include "res://game/scenes/ground_cover.gdshaderinc"
// The wet look of tilled soil, over the soil terrain: where snow lies on the soil (see
// ground_cover.gdshaderinc) the pixel is clear, so the snow of the terrain below shows.

varying vec2 world_position;
varying vec4 modulate;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

void fragment() {
	vec2 art_position = floor(world_position / art_scale) * art_scale;
	vec2 centre = art_position + 0.5 * art_scale;
	COLOR = is_snowed(centre, cover_catch(centre)) ? vec4(0.0) : texture(TEXTURE, UV) * modulate;
}
