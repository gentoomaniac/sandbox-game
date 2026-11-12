// Fallen leaves, frost and snow lying on the ground and on what stands on it, pixel by pixel: the
// rule of game/state/ground_cover.gd (keep the two the same; tests/test_cover_map.gd pins the
// numbers they share). A pixel shows the cover where its threshold in the noise texture is below
// the share of pixels that the weather and the tile's catch make, so a share of 0.3 covers 30 %
// of the pixels in organic patches, and thin cover has soft edges that never follow the tile grid.
//
// The weather of the moment is set once per game minute as global shader parameters (see
// CoverMap and project.godot); what a tile catches comes from a texture with a texel per tile
// (cover_map), which is filtered, so it changes smoothly across tile edges. Needs `art_scale` (see
// art_scale.gdshaderinc) and the world position of the pixel.

// How many leaves, how much snow and thaw, and how much shelter from frost the weather brings.
global uniform float cover_litter;
global uniform float cover_snow;
global uniform float cover_thaw;
global uniform float cover_frost;
// How much of the cover a full thaw takes off a tile that feels all of it ([cover] thaw_gain).
global uniform float cover_thaw_gain;
// How many times the snow share of the ground what stands on it catches ([cover] object_snow_gain).
global uniform float cover_object_snow_gain;
// What the tiles catch: red leaves, green snow, blue melt, alpha frost shelter; a texel per tile,
// in a ring of COVER_MAP_TILES tiles that the world's tiles wrap around (read by `cover_catch`).
global uniform sampler2D cover_map : filter_nearest;
// The thresholds: red for snow, green for frost; and the fallen leaves: colour, with the rank of
// each leaf in the alpha channel (1 to 255; 0 is no leaf). They repeat every COVER_TEXTURE_SIZE
// world pixels, whichever art set is shown (read by `cover_noise_at` and `cover_leaf_at`).
global uniform sampler2D cover_noise : filter_nearest;
global uniform sampler2D cover_leaves : filter_nearest;

// CoverMap.RING_TILES, the width in world pixels of cover_noise and cover_leaves (the art set
// makes them that size, see tools/art/cover.py) and TerrainTileset.TILE_SIZE.
const float COVER_MAP_TILES = 512.0;
const float COVER_TEXTURE_SIZE = 512.0;
const float COVER_TILE = 32.0;

// What the ground at a position of the world (in world pixels) catches: x leaves, y snow, z melt,
// w frost shelter. The texels hold a tile each, as at its middle, and are mixed between the four
// nearest, so it changes smoothly across the edges of the tiles; the world wraps around the ring.
vec4 cover_catch(vec2 position) {
	vec2 tiles = position / COVER_TILE - 0.5;
	vec2 first = floor(tiles);
	vec2 share = tiles - first;
	ivec2 low = ivec2(mod(first, COVER_MAP_TILES));
	ivec2 high = ivec2(mod(first + 1.0, COVER_MAP_TILES));
	vec4 upper = mix(texelFetch(cover_map, low, 0), texelFetch(cover_map, ivec2(high.x, low.y), 0), share.x);
	vec4 lower = mix(texelFetch(cover_map, ivec2(low.x, high.y), 0), texelFetch(cover_map, high, 0), share.x);
	return mix(upper, lower, share.y);
}

// The threshold texel and the fallen leaf at a position of the world (world pixels).
vec4 cover_noise_at(vec2 position) {
	return texture(cover_noise, fract(position / COVER_TEXTURE_SIZE));
}

vec4 cover_leaf_at(vec2 position) {
	return texture(cover_leaves, fract(position / COVER_TEXTURE_SIZE));
}

// The share of the pixels with snow where the tile catches `catch`.
float snow_share(vec4 catch) {
	return clamp(cover_snow * catch.y - cover_thaw * catch.z * cover_thaw_gain, 0.0, 1.0);
}

// Whether the pixel at `centre` (world pixels) is under snow, where the tile catches `catch`.
bool is_snowed(vec2 centre, vec4 catch) {
	float snow = snow_share(catch);
	return snow > 0.0 && snow + 0.002 > cover_noise_at(centre).r;
}

// The pixel at `art_position` (in world pixels, the top left of an art pixel) after the cover:
// `ground` is its colour in the season's look, `frost_colour` and `snow_colour` what it would be
// in the frost and in the snow look (the alpha of `snow_colour` is 0 where the pixel has no snow
// of its own: objects), `brightness` how light it is (frost rimes the light tips first).
vec3 covered(vec3 ground, vec3 frost_colour, vec3 snow_colour, vec2 art_position, float art_pixel, vec4 catch) {
	vec2 centre = art_position + 0.5 * art_pixel;
	vec3 colour = ground;
	vec4 leaf = cover_leaf_at(centre);
	float leaf_rank = (leaf.a * 255.0 - 1.0) / 254.0;
	if (leaf.a > 0.0 && cover_litter * catch.x > leaf_rank) {
		colour = leaf.rgb;
	}
	vec4 noise = cover_noise_at(centre);
	float frost_share = clamp(cover_frost * (1.0 - catch.w), 0.0, 1.0);
	float tip = dot(ground, vec3(0.3, 0.6, 0.1));
	if (frost_share > 0.0 && frost_share + 0.002 > noise.g * (1.15 - 0.6 * tip)) {
		colour = frost_colour;
	}
	if (is_snowed(centre, catch)) {
		colour = snow_colour;
	}
	return colour;
}
