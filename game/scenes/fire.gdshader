shader_type canvas_item;
// A fire that burns: the flame flickers (it jumps a pixel sideways and up or down a few times a
// second, more at the tip), leans downwind and throws sparks that rise, drift with the wind and
// fade. Only the rows of the flame above its logs move, and only within `half_width` of its
// middle, so the fireplace around it stays still. Everything is in whole pixels. For a campfire
// tile (cells of `cell_size` in an atlas without padding) or the hearth's sprite (one cell).
// AmbientMotion sets `lean`; indoors it stays 0.

uniform vec2 cell_size = vec2(48.0, 80.0);
// The flame's rows that move, from its tip to the lowest (in the cell), and its middle column
// (the left of the two middle pixels).
uniform float flame_top = 58.0;
uniform float flame_bottom = 66.0;
uniform float centre_x = 24.0;
uniform float half_width = 7.0;
// Pixels the tip leans (signed, + is right) and sparks rise.
uniform float lean = 0.0;
uniform float spark_rise = 16.0;

const vec3 SPARK_HOT = vec3(0.933, 0.761, 0.353);
const vec3 SPARK_COOL = vec3(0.659, 0.251, 0.180);
const float SPARKS = 4.0;
const float FLICKERS_PER_SECOND = 9.0;

varying vec2 world_position;
varying vec4 modulate;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

// The spark colour at `local`, or alpha 0.
vec4 spark(vec2 local, float seed) {
	for (float i = 0.0; i < SPARKS; i += 1.0) {
		float h = hash(vec2(i, seed));
		float life = 0.9 + 0.6 * h;
		float cycle = floor(TIME / life + h * 5.0);
		float age = fract(TIME / life + h * 5.0);
		float roll = hash(vec2(cycle, i + seed));
		if (roll > 0.6 || age > 0.85) {
			continue;
		}
		vec2 start = vec2(centre_x + floor((roll / 0.6 - 0.5) * 6.0), flame_top + 2.0);
		vec2 at = start + vec2(lean * 3.0 * age + sin(age * 9.0 + h * 20.0) * 1.2, -spark_rise * age);
		if (all(equal(floor(at + 0.5), local))) {
			return vec4(age < 0.4 ? SPARK_HOT : SPARK_COOL, 1.0);
		}
	}
	return vec4(0.0);
}

void fragment() {
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 local = mod(texel, cell_size);
	float seed = hash(floor(world_position) - local);
	vec4 shown = texture(TEXTURE, UV);
	bool is_in_flame = abs(local.x + 0.5 - centre_x) <= half_width;
	if (is_in_flame && local.y >= flame_top - 2.0 && local.y <= flame_bottom) {
		// 0 at the lowest moving row, 1 at the tip.
		float up = (flame_bottom - local.y) / (flame_bottom - flame_top);
		float step = floor(TIME * FLICKERS_PER_SECOND);
		float jitter = hash(vec2(step, seed)) - 0.5;
		float stretch = hash(vec2(seed, step)) > 0.65 && up > 0.4 ? 1.0 : 0.0;
		float shift = lean * up * up + jitter * 1.6 * up;
		shift = sign(shift) * floor(abs(shift) + 0.5);
		vec2 source = local + vec2(-shift, stretch);
		source.x = clamp(source.x, centre_x - half_width, centre_x + half_width - 1.0);
		shown = texture(TEXTURE, (texel - local + source + 0.5) * TEXTURE_PIXEL_SIZE);
	}
	vec4 lit = spark(local, seed);
	if (lit.a > 0.0) {
		shown = lit;
	}
	COLOR = shown * modulate;
}
