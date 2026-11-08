shader_type canvas_item;
// Draws pixel art at any scale with square pixels, as sharp_bilinear.gdshader does for the world:
// every texel a flat square, only a one window pixel wide strip at its edge blended with its
// neighbour, so that a 32 px icon shown at 1.5 window pixels per texel keeps straight edges.
// The scale is how far one window pixel steps through the texture. Needs a linear texture
// filter (see ItemIcon.sharpen).

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * texture_size;
	vec2 texels_per_pixel = max(fwidth(texel), vec2(1e-4));
	vec2 flat_half = max(0.5 - 0.5 * texels_per_pixel, 0.0);
	vec2 from_center = fract(texel) - 0.5;
	vec2 blended = (from_center - clamp(from_center, -flat_half, flat_half)) / texels_per_pixel + 0.5;
	COLOR = texture(TEXTURE, (floor(texel) + blended) / texture_size) * modulate;
}
