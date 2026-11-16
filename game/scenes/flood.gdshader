shader_type canvas_item;
#include "res://game/scenes/hash.gdshaderinc"
#include "res://game/scenes/art_scale.gdshaderinc"
#include "res://game/scenes/water_surface.gdshaderinc"
// The water a storm surge leaves on the land (FloodOverlay): a mask texture of a chunk, one pixel a
// tile, whose red is the water's depth in centimetres (0 for dry ground, 255 for 2.55 m and
// deeper). The ground is not changed: the water is drawn over it, like the sea over the mud,
// moving as the river does (see water_surface.gdshaderinc). Shallow water lets the ground show
// through; deep water hides it.

// Up to this depth (metres) the water is a thin sheet; the ground below shows through.
const float SHALLOW = 0.35;
const float SHALLOW_OPACITY = 0.55;
const float DEEP_OPACITY = 0.9;
// The depth (metres) at which the water is as opaque as it gets.
const float OPAQUE_AT = 1.5;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float depth = texture(TEXTURE, UV).r * 255.0 / 100.0;
	if (depth <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec2 p = floor(world_position / art_scale);
		vec3 surface = depth > SHALLOW ? water_surface(p) : WATER_LIGHT;
		float opacity = mix(SHALLOW_OPACITY, DEEP_OPACITY, clamp(depth / OPAQUE_AT, 0.0, 1.0));
		COLOR = vec4(surface, opacity);
	}
}
