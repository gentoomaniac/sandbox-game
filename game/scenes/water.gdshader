shader_type canvas_item;
// Water that moves: short ripples that come and go and drift with the wind, and the odd glint,
// all in whole pixels and anchored to the world. Only pixels of plain water change, so the
// marks, banks and foam of the tiles stay as they are. The wind makes it choppy (`chop`, 0 to
// 1): more, faster ripples, crests and glints. AmbientMotion sets `chop` and how far the
// ripples have drifted (`drift`, pixels). On the water layer of the terrain.

uniform float chop : hint_range(0.0, 1.0) = 0.0;
uniform vec2 drift = vec2(0.0);

// The palette's water colours (tools/art/generate.py).
const vec3 WATER = vec3(0.220, 0.361, 0.475);
const vec3 WATER_DEEP = vec3(0.169, 0.271, 0.380);
const vec3 WATER_LIGHT = vec3(0.314, 0.482, 0.576);
const vec3 FOAM = vec3(0.573, 0.706, 0.741);
const vec2 RIPPLE_CELL = vec2(22.0, 8.0);
const vec2 GLINT_CELL = vec2(14.0, 12.0);

varying vec2 world_position;
varying vec4 modulate;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 hash4(vec2 cell, float layer) {
	vec2 c = cell + layer * 17.31;
	return vec4(hash(c), hash(c + 3.7), hash(c + 9.1), hash(c + 15.3));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

// The colour a ripple gives the pixel at `p`, or alpha 0.
vec4 ripple(vec2 p) {
	vec2 q = floor(p - drift);
	vec2 cell = floor(q / RIPPLE_CELL);
	vec4 h = hash4(cell, 1.0);
	if (h.w > 0.18 + 0.5 * chop) {
		return vec4(0.0);
	}
	float age = fract(TIME / mix(5.0, 1.8, chop) + h.z * 7.0);
	if (age > 0.55) {
		return vec4(0.0);
	}
	float length = 2.0 + floor(h.z * 3.0 + chop * 2.0);
	vec2 start = floor(vec2(h.x * (RIPPLE_CELL.x - length), h.y * RIPPLE_CELL.y));
	vec2 local = q - cell * RIPPLE_CELL - start;
	if (local.y != 0.0 || local.x < 0.0 || local.x >= length) {
		return vec4(0.0);
	}
	// In wind a ripple's leading pixel catches the light, and in a storm it breaks into foam.
	if (chop > 0.35 && local.x == length - 1.0) {
		return vec4(chop > 0.75 && h.x < 0.5 ? FOAM : WATER_LIGHT, 1.0);
	}
	return vec4(WATER_DEEP, 1.0);
}

float glint(vec2 p) {
	vec2 q = floor(p - drift * 0.5);
	vec2 cell = floor(q / GLINT_CELL);
	vec4 h = hash4(cell, 2.0);
	if (h.w > 0.1 + 0.3 * chop) {
		return 0.0;
	}
	if (fract(TIME * (0.2 + 0.6 * chop) + h.z * 11.0) > 0.12) {
		return 0.0;
	}
	vec2 spot = floor(vec2(h.x * (GLINT_CELL.x - 2.0), h.y * GLINT_CELL.y));
	vec2 local = q - cell * GLINT_CELL - spot;
	return local.y == 0.0 && local.x >= 0.0 && local.x < 2.0 ? 1.0 : 0.0;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a > 0.0 && distance(base.rgb, WATER) < 0.02) {
		vec2 p = floor(world_position);
		vec4 r = ripple(p);
		if (r.a > 0.0) {
			COLOR.rgb = r.rgb * modulate.rgb;
		} else if (glint(p) > 0.0) {
			COLOR.rgb = WATER_LIGHT * modulate.rgb;
		}
	}
}
