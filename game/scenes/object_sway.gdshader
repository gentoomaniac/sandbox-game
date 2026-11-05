shader_type canvas_item;
// A plant of the objects layer (a tree, bush, tall grass, reeds or a crop) swaying in the
// wind: each row of its picture is moved sideways by whole pixels, nothing at its stem and
// most at its top, so it bends over its fixed foot. Set on the tiles of the plant's type (see
// AmbientMotion and ObjectTileset), which are cells of `cell_size` in an atlas without padding:
// the texture coordinates say where in its cell a pixel is.

#include "res://game/scenes/sway.gdshaderinc"

uniform vec2 cell_size = vec2(48.0, 80.0);
// Pixels above the cell's bottom: up to `stem` nothing moves, at `top` it bends the most.
uniform float stem = 0.0;
uniform float top = 16.0;
// How far this kind of plant bends, as a share of the wind's sway.
uniform float strength = 1.0;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

void fragment() {
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 local = mod(texel, cell_size);
	vec2 origin = floor(world_position) - local;
	float height = cell_size.y - 1.0 - local.y;
	float bend = smoothstep(stem, top, height);
	float shift = whole_pixels(sway_at(origin) * strength * bend);
	float source_x = local.x - shift;
	if (source_x < 0.0 || source_x >= cell_size.x) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, (texel + vec2(-shift, 0.0) + 0.5) * TEXTURE_PIXEL_SIZE) * modulate;
	}
}
