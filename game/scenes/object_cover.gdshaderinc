// Frost and snow on what stands on the ground: trees, bushes, stones, fences and the like (see
// ground_cover.gdshaderinc for the weather and what a tile catches). The art generator draws only
// the pixels that the frost and the snow add to each picture, in atlases with the layout of the
// picture's own (tools/art/cover.py); the alpha channel of a pixel there is its rank, 1 to 255,
// which grows from the top of the picture down for the snow and is random for the frost. A pixel
// shows the cover once the share of cover that the ground the object stands on gets is above its
// rank, so the snow settles on a tree from the top down and thickens, and thaws from the bottom
// up, whatever the season's picture the tree has.
global uniform sampler2D cover_objects_snow : filter_nearest;
global uniform sampler2D cover_objects_frost : filter_nearest;

// The rank of a pixel of a cover atlas, 0 to 1, from its alpha.
float cover_rank(float alpha) {
	return (alpha * 255.0 - 1.0) / 254.0;
}

// The ground a picture stands on: the middle of the tile at the foot of the cell whose top left
// is `origin` and whose size is `cell_size` (both in art pixels, of `art_pixel` world pixels). A
// picture several cells wide has each cell on its own ground, a little to the side of the
// picture's middle, which the cover does not tell apart (it is smooth across tiles).
vec2 cell_anchor(vec2 origin, vec2 cell_size, float art_pixel) {
	return (origin + vec2(cell_size.x * 0.5, cell_size.y)) * art_pixel - vec2(0.0, 0.5 * COVER_TILE);
}

// The share of snow that what stands on the ground catches, where the ground catches `catch`.
float object_snow_share(vec4 catch) {
	return clamp(snow_share(catch) * cover_object_snow_gain, 0.0, 1.0);
}

// The pixel `base` of a picture at `uv` with the frost and the snow over it, where the ground at
// `anchor` (world pixels, under the object) catches what it does. A clear pixel stays clear.
vec4 object_covered(vec4 base, vec2 uv, vec2 anchor) {
	if (base.a == 0.0) {
		return base;
	}
	vec4 catch = cover_catch(anchor);
	// Nothing shows where there is no cover: a pixel of rank 0 would pass the bias alone.
	float frost_share = clamp(cover_frost * (1.0 - catch.w), 0.0, 1.0);
	vec4 frost = texture(cover_objects_frost, uv);
	if (frost_share > 0.0 && frost.a > 0.0 && frost_share + 0.002 > cover_rank(frost.a)) {
		base.rgb = frost.rgb;
	}
	float snow_cover_share = object_snow_share(catch);
	vec4 snow = texture(cover_objects_snow, uv);
	if (snow_cover_share > 0.0 && snow.a > 0.0 && snow_cover_share + 0.002 > cover_rank(snow.a)) {
		base.rgb = snow.rgb;
	}
	return base;
}
