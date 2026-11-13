extends GutTest
## The picture of a bolt: a core of one colour in a glow of another and nothing else, both of
## them colours of the art's palette.

const SIZE := Vector2i(644, 364)
const PALETTE_SOURCES := ["res://tools/art/palette.py", "res://tools/art/seasons.py"]


func test_the_picture_is_a_core_in_a_glow_and_nothing_else() -> void:
	var image := BoltImage.render(LightningBolt.new(5, SIZE), SIZE)
	assert_eq(image.get_size(), SIZE)
	var colours := {}
	for y in SIZE.y:
		for x in SIZE.x:
			colours[image.get_pixel(x, y).to_rgba32()] = true
	assert_eq(colours.size(), 3, "see-through, glow and core: %s" % [colours.keys()])
	assert_true(colours.has(BoltImage.CORE_COLOR.to_rgba32()))
	assert_true(colours.has(BoltImage.GLOW_COLOR.to_rgba32()))


func test_the_core_is_wider_in_the_main_channel_than_in_a_branch() -> void:
	var bolt := LightningBolt.new(5, SIZE)
	var image := BoltImage.render(bolt, SIZE)
	var start := Vector2i(bolt.paths[LightningBolt.MAIN][0].round())
	assert_eq(image.get_pixelv(start).to_rgba32(), BoltImage.CORE_COLOR.to_rgba32())
	assert_eq(
		image.get_pixelv(start + Vector2i.RIGHT).to_rgba32(), BoltImage.CORE_COLOR.to_rgba32()
	)


func test_the_colours_are_in_the_palette() -> void:
	var palette := _palette_rgb_values()
	assert_gt(palette.size(), 0, "palette parsed")
	for color: Color in [BoltImage.CORE_COLOR, BoltImage.GLOW_COLOR]:
		assert_true(
			palette.has(color.to_html(false)), "%s is a palette colour" % color.to_html(false)
		)


## The hex values of the palette, from lines like `    "water":          "385c79",`.
func _palette_rgb_values() -> Array[String]:
	var regex := RegEx.create_from_string('^\\s*"(\\w+)":\\s*"([0-9a-fA-F]{6})",')
	var values: Array[String] = []
	for source in PALETTE_SOURCES:
		for line in FileAccess.get_file_as_string(source).split("\n"):
			var found := regex.search(line)
			if found:
				values.append(found.get_string(2).to_lower())
	return values
