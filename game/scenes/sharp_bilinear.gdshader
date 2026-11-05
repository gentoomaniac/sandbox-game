shader_type canvas_item;
// Shows `region_size` texels of the world image, from `region_origin`, over the whole rect.
// Every texel becomes a flat square of `texels_to_pixels` window pixels; only a one pixel
// wide strip at the edge of a texel is blended with its neighbour, so that texel edges
// are straight at any scale ("sharp bilinear"). Needs a linear texture filter.

uniform vec2 region_origin;
uniform vec2 region_size;
uniform float texels_to_pixels = 3.0;

void fragment() {
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = region_origin + UV * region_size;
	// Below one window pixel per texel there is no flat part to keep.
	float scale = max(texels_to_pixels, 1.0);
	float flat_half = 0.5 - 0.5 / scale;
	vec2 from_center = fract(texel) - 0.5;
	vec2 blended = (from_center - clamp(from_center, -flat_half, flat_half)) * scale + 0.5;
	COLOR = texture(TEXTURE, (floor(texel) + blended) / texture_size);
}
