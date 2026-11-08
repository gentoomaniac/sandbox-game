shader_type canvas_item;
// Shows `region_size` texels of the world image, from `region_origin`, over the whole rect.
// Every texel becomes a flat square of `texels_to_pixels` window pixels; only a one pixel
// wide strip at the edge of a texel is blended with its neighbour, so that texel edges
// are straight at any scale ("sharp bilinear"). Below one window pixel per texel (small
// windows at the widest view) a pixel covers several texels, so it averages four bilinear
// samples over its footprint instead, which keeps thin lines from flickering as the world
// scrolls. Needs a linear texture filter.

uniform vec2 region_origin;
uniform vec2 region_size;
uniform float texels_to_pixels = 3.0;

void fragment() {
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = region_origin + UV * region_size;
	if (texels_to_pixels < 1.0) {
		vec2 reach = vec2(0.25 / texels_to_pixels);
		vec4 sum = vec4(0.0);
		for (int i = 0; i < 4; i++) {
			vec2 corner = vec2(float(i % 2) * 2.0 - 1.0, float(i / 2) * 2.0 - 1.0);
			sum += texture(TEXTURE, (texel + corner * reach) / texture_size);
		}
		COLOR = sum / 4.0;
	} else {
		float flat_half = 0.5 - 0.5 / texels_to_pixels;
		vec2 from_center = fract(texel) - 0.5;
		vec2 blended = (from_center - clamp(from_center, -flat_half, flat_half)) * texels_to_pixels + 0.5;
		COLOR = texture(TEXTURE, (floor(texel) + blended) / texture_size);
	}
}
