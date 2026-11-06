// Noise shared by the shaders: a hash of a position, and four hashes of a cell and a layer.

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 hash4(vec2 cell, float layer) {
	vec2 c = cell + layer * 17.31;
	return vec4(hash(c), hash(c + 3.7), hash(c + 9.1), hash(c + 15.3));
}
