shader_type canvas_item;
// The little plants of the decoration layer (flowers, tufts, ferns, reeds) swaying in the
// wind. Their pictures are a few pixels high and sit anywhere in their tile, so a pixel's
// height is the run of opaque pixels below it: the bottom pixel of a stem stays put, the one
// above moves at most one pixel, and so do the ones above that, but sooner. Set on the
// decoration tiles that sway (see AmbientMotion and TerrainTileset), in an atlas without padding.

#include "res://game/scenes/art_scale.gdshaderinc"
#include "res://game/scenes/sway.gdshaderinc"

// A tile in art pixels, the 16 px art's (in art pixels, as everything below).
const float TILE = 16.0;
// How far these plants bend, as a share of the wind's sway.
uniform float strength = 0.5;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

// How far the sway `offset` moves a pixel that has `height` opaque pixels below it in its
// stem (at most 2): 0, 1 or -1.
float shift_of(float height, float offset) {
	return clamp(whole_pixels(offset * height / 2.0), -1.0, 1.0);
}

void fragment() {
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE / art_scale);
	vec2 local = mod(texel, TILE);
	vec2 origin = floor(world_position / art_scale) - local;
	float offset = sway_at(origin) * strength;
	float direction = clamp(whole_pixels(offset), -1.0, 1.0);
	// The pixel shows the one the sway moves onto it (`moved`, from the column against the
	// sway), else its own if that one stays.
	vec2 moved_local = local - vec2(direction, 0.0);
	vec4 own = vec4(0.0);
	vec4 moved = vec4(0.0);
	float own_height = 0.0;
	float moved_height = 0.0;
	bool own_stem = true;
	bool moved_stem = true;
	for (float below = 0.0; below <= 2.0; below += 1.0) {
		bool in_tile = local.y + below < TILE;
		vec2 own_source = (texel + vec2(0.0, below)) * art_scale + 0.5;
		vec2 moved_source = (texel + vec2(-direction, below)) * art_scale + 0.5;
		vec4 own_texel = texture(TEXTURE, own_source * TEXTURE_PIXEL_SIZE);
		vec4 moved_texel = texture(TEXTURE, moved_source * TEXTURE_PIXEL_SIZE);
		if (below == 0.0) {
			own = own_texel;
			moved = moved_texel;
			continue;
		}
		own_stem = own_stem && in_tile && own_texel.a > 0.0;
		moved_stem = moved_stem && in_tile && moved_texel.a > 0.0;
		own_height += own_stem ? 1.0 : 0.0;
		moved_height += moved_stem ? 1.0 : 0.0;
	}
	bool is_moved_in_tile = moved_local.x >= 0.0 && moved_local.x < TILE;
	vec4 shown = vec4(0.0);
	if (direction != 0.0 && is_moved_in_tile && moved.a > 0.0
			&& shift_of(moved_height, offset) == direction) {
		shown = moved;
	} else if (own.a > 0.0 && shift_of(own_height, offset) == 0.0) {
		shown = own;
	}
	COLOR = shown * modulate;
}
