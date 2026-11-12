shader_type canvas_item;
#include "res://game/scenes/ground_cover.gdshaderinc"
#include "res://game/scenes/object_cover.gdshaderinc"
// Makes a sprite translucent inside a soft-edged circle (in world pixels), so what stands
// behind it shows. `fade` blends the effect in and out (0 = the plain sprite). The sprite of an
// object of the objects atlas (a tree that stands in for its cell, a falling tree) has the frost
// and snow of the weather over it like the cell has (see object_cover.gdshaderinc), on the ground
// at `cover_anchor`: the uv of the atlas picture finds the same pixel in the cover atlases.

uniform vec2 circle_centre;
uniform float radius = 24.0;
uniform float inner_opacity = 0.35;
uniform float edge_softness = 4.0;
uniform float fade = 0.0;
uniform bool has_cover = false;
uniform vec2 cover_anchor;
// The snow on the roof of a house, in a picture of the house's size (see tools/art/cover.py),
// the rank of each pixel in its alpha as in the atlases of the objects.
uniform bool has_roof_snow = false;
uniform sampler2D roof_snow : filter_nearest;

varying vec2 world_position;
varying vec4 modulate;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

void fragment() {
	if (has_cover) {
		COLOR = object_covered(texture(TEXTURE, UV), UV, cover_anchor) * modulate;
	}
	if (has_roof_snow) {
		vec4 snow = texture(roof_snow, UV);
		float share = object_snow_share(cover_catch(cover_anchor));
		if (share > 0.0 && snow.a > 0.0 && share + 0.002 > cover_rank(snow.a)) {
			COLOR.rgb = snow.rgb * modulate.rgb;
		}
	}
	float inside = 1.0 - smoothstep(radius - edge_softness, radius, distance(world_position, circle_centre));
	COLOR.a *= mix(1.0, inner_opacity, inside * fade);
}
