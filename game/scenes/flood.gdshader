shader_type canvas_item;
#include "res://game/scenes/hash.gdshaderinc"
#include "res://game/scenes/art_scale.gdshaderinc"
#include "res://game/scenes/water_surface.gdshaderinc"
// The water a storm surge leaves on the land (FloodOverlay): a mask texture of a chunk, one pixel a
// tile, whose red is the water's depth in centimetres (0 for dry ground, 255 for 2.55 m and
// deeper), with a ring of the neighbouring tiles around it. The ground is not changed: the water is
// drawn over it, like the sea over the mud, moving as the river does (see
// water_surface.gdshaderinc). Shallow water lets the ground show through; deep water hides it.
// The mask is read with a linear filter, so the depth between two tiles is smooth: the edge of the
// water is a soft line where it falls under EDGE_TO, not the tiles' steps, and the shore darkens
// like wet ground.

// Up to this depth (metres) the water is a thin sheet; the ground below shows through.
const float SHALLOW = 0.35;
const float SHALLOW_OPACITY = 0.55;
const float DEEP_OPACITY = 0.9;
// The depth (metres) at which the water is as opaque as it gets.
const float OPAQUE_AT = 1.5;
// The depths (metres) over which the water fades in at its edge.
const float EDGE_FROM = 0.02;
const float EDGE_TO = 0.12;
// The depth (metres) up to which the shore is darkened, and how much at the very edge.
const float SHORE_WIDTH = 0.4;
const float SHORE_DARKEN = 0.55;
// palette: tools/art/palette.py (mud_dark, the wet ground; tests/test_shader_palette.gd guards it)
const vec3 SHORE = vec3(0.310, 0.267, 0.212);

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// The ring around the chunk only feeds the filter: its tiles are drawn by their own chunk.
	vec2 texels = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * texels;
	float depth = texture(TEXTURE, UV).r * 255.0 / 100.0;
	bool in_ring = texel.x < 1.0 || texel.y < 1.0 || texel.x > texels.x - 1.0 || texel.y > texels.y - 1.0;
	if (in_ring || depth <= EDGE_FROM) {
		COLOR = vec4(0.0);
	} else {
		vec2 p = floor(world_position / art_scale);
		vec3 surface = mix(WATER_LIGHT, water_surface(p), smoothstep(SHALLOW, SHALLOW * 1.4, depth));
		float shore = SHORE_DARKEN * (1.0 - smoothstep(EDGE_FROM, SHORE_WIDTH, depth));
		float opacity = mix(SHALLOW_OPACITY, DEEP_OPACITY, clamp(depth / OPAQUE_AT, 0.0, 1.0));
		COLOR = vec4(mix(surface, SHORE, shore), opacity * smoothstep(EDGE_FROM, EDGE_TO, depth));
	}
}
