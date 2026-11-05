shader_type canvas_item;
// A fire that burns: its flame plays a loop of frames (drawn by tools/art/fire.py), leans and
// stretches downwind and throws sparks that rise, drift with the wind and fade. For a campfire
// tile (cells of `cell_size` in an atlas without padding) or the hearth's sprite (one cell).
//
// The flame burns in a box of the cell. The strip `flames` has cells of the box's size: what
// is behind the flame, what is in front of it, then the flame's `frames` frames. Inside the box
// the shader draws them over each other instead of the picture (which shows the first frame,
// for where the fire does not move), so the logs and stones stay still and only the flame
// moves. Each fire starts its loop at its own frame, picked by its place, so two fires do not
// burn in step (see AmbientMotion.fire_frame, which picks the same). Everything is in whole
// pixels. AmbientMotion sets `lean` and `stretch`; indoors they stay 0.

uniform vec2 cell_size = vec2(48.0, 80.0);
uniform sampler2D flames : filter_nearest;
// The top left of the flame's box in the cell.
uniform vec2 box_position = vec2(16.0, 51.0);
uniform int frames = 6;
uniform float frames_per_second = 9.0;
// The row the flame's tip usually reaches, where the sparks fly from, and how high they rise.
uniform float flame_top = 57.0;
uniform float spark_rise = 16.0;
// Pixels the top of the box leans (signed, + is right), and how much taller the flame grows
// (a share of its height).
uniform float lean = 0.0;
uniform float stretch = 0.0;

const vec3 SPARK_HOT = vec3(0.933, 0.761, 0.353);
const vec3 SPARK_COOL = vec3(0.659, 0.251, 0.180);
const float SPARKS = 4.0;

varying vec2 world_position;
varying vec4 modulate;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// PositionHash.of with no salt.
uint position_hash(ivec2 pos) {
	uint h = uint(pos.x) * 0x9E3779B1u;
	h ^= h >> 15u;
	h = (h ^ uint(pos.y)) * 0x85EBCA6Bu;
	h ^= h >> 13u;
	h *= 0xC2B2AE35u;
	return h ^ (h >> 16u);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate = COLOR;
}

// The flame, or what is in front of or behind it, at `in_box` (pixels in the box of size `box`)
// of the fire whose cell is at `origin`.
vec4 burning(ivec2 in_box, ivec2 box, vec2 origin) {
	vec4 front = texelFetch(flames, in_box + ivec2(box.x, 0), 0);
	if (front.a > 0.0) {
		return front;
	}
	int phase = int(position_hash(ivec2(origin)) % uint(frames));
	int frame = (int(floor(TIME * frames_per_second)) + phase) % frames;
	// Rows above the box's bottom; the higher, the further it leans.
	float rise = float(box.y - 1 - in_box.y);
	float up = rise / float(box.y - 1);
	int source_x = in_box.x - int(round(lean * up * up));
	int source_y = box.y - 1 - int(round(rise / (1.0 + stretch)));
	if (source_x >= 0 && source_x < box.x) {
		vec4 flame = texelFetch(flames, ivec2((frame + 2) * box.x + source_x, source_y), 0);
		if (flame.a > 0.0) {
			return flame;
		}
	}
	return texelFetch(flames, in_box, 0);
}

// The spark colour at `local`, or alpha 0.
vec4 spark(vec2 local, float centre_x, float seed) {
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
		vec2 at = start + vec2(lean * 1.5 * age + sin(age * 9.0 + h * 20.0) * 1.2, -spark_rise * age);
		if (all(equal(floor(at + 0.5), local))) {
			return vec4(age < 0.4 ? SPARK_HOT : SPARK_COOL, 1.0);
		}
	}
	return vec4(0.0);
}

void fragment() {
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 local = mod(texel, cell_size);
	vec2 origin = floor(world_position) - local;
	ivec2 box = textureSize(flames, 0) / ivec2(frames + 2, 1);
	ivec2 in_box = ivec2(local - box_position);
	vec4 shown = texture(TEXTURE, UV);
	if (all(greaterThanEqual(in_box, ivec2(0))) && all(lessThan(in_box, box))) {
		shown = burning(in_box, box, origin);
	}
	vec4 lit = spark(local, box_position.x + float(box.x) / 2.0, hash(origin));
	if (lit.a > 0.0) {
		shown = lit;
	}
	COLOR = shown * modulate;
}
