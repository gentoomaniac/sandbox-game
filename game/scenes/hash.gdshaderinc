// Noise shared by the shaders: a hash of a position, and four hashes of a cell and a layer.

// A value in [0, 1) from the bits of the position, by integer arithmetic only (PCG2D, Jarzynski and
// Olano), so every GPU and driver gives the same value. The sine hash this replaces gave different
// values per GPU for large coordinates, which showed as hard-edged blocks.
float hash(vec2 p) {
	// -0.0 has other bits than 0.0: a position that reached zero by a product must hash like zero.
	uvec2 v = floatBitsToUint(p) * uvec2(notEqual(p, vec2(0.0)));
	v = v * 1664525u + 1013904223u;
	v.x += v.y * 1664525u;
	v.y += v.x * 1664525u;
	v ^= v >> 16u;
	v.x += v.y * 1664525u;
	v.y += v.x * 1664525u;
	v ^= v >> 16u;
	// The top 24 bits fit a float's mantissa exactly.
	return float(v.x >> 8u) / 16777216.0;
}

vec4 hash4(vec2 cell, float layer) {
	vec2 c = cell + layer * 17.31;
	return vec4(hash(c), hash(c + 3.7), hash(c + 9.1), hash(c + 15.3));
}
