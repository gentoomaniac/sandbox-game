shader_type canvas_item;
#include "res://game/scenes/hash.gdshaderinc"
#include "res://game/scenes/art_scale.gdshaderinc"
#include "res://game/scenes/water_surface.gdshaderinc"
#include "res://game/scenes/ground_look.gdshaderinc"
// A ford, where a creek runs shallow over its stones (issue #96): its stones take the colour of the
// ground's looks with the leaves, frost and snow of the weather over them (see
// ground_look.gdshaderinc), and the plain water between them moves as the creek's does (see
// water_surface.gdshaderinc), so the creek runs into the ford without a seam. On the ford layer of
// the terrain; AmbientMotion gives it the wind and GroundLook the looks.

varying vec2 world_position;
varying vec4 modulate;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

void fragment() {
	float drawn = texture(TEXTURE, UV).a;
	if (drawn == 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 colour = ground_pixel(UV, drawn, world_position, art_scale);
		if (distance(colour.rgb, WATER) < 0.02) {
			colour.rgb = water_surface(floor(world_position / art_scale));
		}
		COLOR = colour * modulate;
	}
}
