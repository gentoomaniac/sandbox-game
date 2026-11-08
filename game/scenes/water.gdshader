shader_type canvas_item;
#include "res://game/scenes/hash.gdshaderinc"
#include "res://game/scenes/art_scale.gdshaderinc"
#include "res://game/scenes/water_surface.gdshaderinc"
// Water that moves (see water_surface.gdshaderinc). Only pixels of plain water change, so the
// marks, banks and foam of the tiles stay as they are. On the water layer of the terrain.

varying vec2 world_position;
varying vec4 modulate;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a > 0.0 && distance(base.rgb, WATER) < 0.02) {
		COLOR.rgb = water_surface(floor(world_position / art_scale)) * modulate.rgb;
	}
}
