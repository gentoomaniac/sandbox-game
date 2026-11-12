// The colour of the ground and what lies on it, for a pixel of a tile of the terrain or decoration
// atlases (see GroundLook). The atlases of all the looks of the ground (tools/art/seasons.py) have
// the same layout, so one coordinate finds the same pixel in each. The picture the tile has
// (TEXTURE, the summer atlas, in an atlas without padding) only says which pixels are drawn; the
// colour is the one of the season the ground is leaving (`from_look`) mixed into the one it is
// going to (`to_look`) by `mix_share`, evenly all over the world, and the fallen leaves, frost and
// snow of the weather come over it (see ground_cover.gdshaderinc), the frost and the snow in the
// colours of the frost and snow looks.
#include "res://game/scenes/ground_cover.gdshaderinc"

uniform sampler2D from_look : filter_nearest;
uniform sampler2D to_look : filter_nearest;
uniform sampler2D frost_look : filter_nearest;
uniform sampler2D snow_look : filter_nearest;
uniform float mix_share : hint_range(0.0, 1.0) = 1.0;

// The pixel at `uv` of the atlas (its alpha in the picture is `drawn`) on the screen at
// `position`, whose art pixels are `art_pixel` world pixels wide.
vec4 ground_pixel(vec2 uv, float drawn, vec2 position, float art_pixel) {
	vec3 ground = mix(texture(from_look, uv).rgb, texture(to_look, uv).rgb, mix_share);
	vec2 art_position = floor(position / art_pixel) * art_pixel;
	vec4 catch = cover_catch(art_position + 0.5 * art_pixel);
	vec3 colour = covered(ground, texture(frost_look, uv).rgb, texture(snow_look, uv).rgb, art_position, art_pixel, catch);
	return vec4(colour, drawn);
}
