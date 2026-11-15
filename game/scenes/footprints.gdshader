shader_type canvas_item;
// The footprints of a chunk (see FootprintView): one quad each, with the age of its kind when it
// was made (custom data x) and its cell of the sheet (custom data y: 0 and 1 the feet in snow,
// 2 and 3 those in mud, see tools/art/footprints.py). It fades by how old the weather has made the
// prints of its kind since (see Footprints `opacity_of`, which this does the same as), so the
// game does nothing to a print as it ages.

uniform float snow_age;
uniform float mud_age;
uniform float snow_lasts_minutes;
uniform float mud_lasts_minutes;

const float CELLS = 4.0;

varying float opacity;

void vertex() {
	float cell = INSTANCE_CUSTOM.y;
	bool is_snow = cell < 2.0;
	float age = (is_snow ? snow_age : mud_age) - INSTANCE_CUSTOM.x;
	opacity = clamp(1.0 - age / (is_snow ? snow_lasts_minutes : mud_lasts_minutes), 0.0, 1.0);
	UV = (UV + vec2(cell, 0.0)) / vec2(CELLS, 1.0);
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= opacity;
}
