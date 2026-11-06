extends GutTest
## The water and fire shaders compare pixels against copies of palette colours. If the
## palette in tools/art/palette.py changes, these copies must change with it, or the ripples
## and sparks silently stop showing.

const PALETTE_SOURCE := "res://tools/art/palette.py"
## Shader file -> {shader constant: palette colour name}.
const COPIES := {
	"res://game/scenes/water.gdshader":
	{
		"WATER": "water",
		"WATER_DEEP": "water_deep",
		"WATER_LIGHT": "water_light",
		"FOAM": "foam",
	},
	"res://game/scenes/fire.gdshader": {"SPARK_HOT": "gold", "SPARK_COOL": "ember"},
}


func test_shader_colours_match_the_palette() -> void:
	var palette := _palette()
	assert_false(palette.is_empty(), "palette parsed from %s" % PALETTE_SOURCE)
	for path: String in COPIES:
		var constants := _shader_colours(path)
		for constant: String in COPIES[path]:
			var colour_name: String = COPIES[path][constant]
			assert_true(constants.has(constant), "%s defines %s" % [path, constant])
			assert_true(palette.has(colour_name), "palette has %s" % colour_name)
			if constants.has(constant) and palette.has(colour_name):
				var where := "%s %s vs palette %s" % [path, constant, colour_name]
				var difference: float = constants[constant].distance_to(palette[colour_name])
				assert_lt(difference, 0.003, where)


## Palette name -> colour, from lines like `    "water":          "385c79",`.
func _palette() -> Dictionary:
	var regex := RegEx.create_from_string('^\\s*"(\\w+)":\\s*"([0-9a-fA-F]{6})",')
	var colours := {}
	for line in FileAccess.get_file_as_string(PALETTE_SOURCE).split("\n"):
		var found := regex.search(line)
		if found:
			var colour := Color.html(found.get_string(2))
			colours[found.get_string(1)] = Vector3(colour.r, colour.g, colour.b)
	return colours


## Constant name -> colour, from lines like `const vec3 WATER = vec3(0.220, 0.361, 0.475);`.
func _shader_colours(path: String) -> Dictionary:
	var number := "([0-9.]+)"
	var pattern := "const vec3 (\\w+) = vec3\\(%s, %s, %s\\);" % [number, number, number]
	var regex := RegEx.create_from_string(pattern)
	var colours := {}
	for found in regex.search_all(FileAccess.get_file_as_string(path)):
		colours[found.get_string(1)] = Vector3(
			float(found.get_string(2)), float(found.get_string(3)), float(found.get_string(4))
		)
	return colours
