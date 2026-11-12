extends GutTest
## The tide: high water twice a day, a little later each day.


func test_high_water_comes_back_every_twelve_hours_and_a_quarter() -> void:
	assert_almost_eq(Tide.level(0.0), 1.0, 0.0001)
	assert_almost_eq(Tide.level(Tide.PERIOD_MINUTES), 1.0, 0.0001)
	assert_almost_eq(Tide.level(Tide.PERIOD_MINUTES / 2.0), 0.0, 0.0001)


func test_the_water_stands_between_low_and_high() -> void:
	for minute in range(0, GameClock.MINUTES_PER_DAY * 3, 17):
		var level := Tide.level(minute)
		assert_between(level, 0.0, 1.0, str(minute))


func test_high_water_is_later_each_day() -> void:
	var first_day := Tide.level(GameClock.MINUTES_PER_DAY)
	var next_day := Tide.level(2 * GameClock.MINUTES_PER_DAY)
	assert_ne(first_day, next_day, "the same time of day, another tide")


## The shader's text, to compare the ported relief with.
func _shader_source() -> String:
	return FileAccess.get_file_as_string("res://game/scenes/mud.gdshader")


func _shader_float(constant: String) -> float:
	var found := RegEx.create_from_string("const float %s = ([0-9.]+);" % constant).search(
		_shader_source()
	)
	assert_not_null(found, "%s in mud.gdshader" % constant)
	return float(found.get_string(1))


func test_the_relief_is_the_one_of_the_shader() -> void:
	assert_eq(Tide.LOW_WATER, _shader_float("LOW_WATER"))
	assert_eq(Tide.HIGH_WATER, _shader_float("HIGH_WATER"))
	assert_eq(Tide.SWELL_SIZE, _shader_float("SWELL_SIZE"))
	assert_eq(Tide.HOLLOW_SIZE, _shader_float("HOLLOW_SIZE"))
	var source := _shader_source()
	for multiplier in [Tide.HASH_X, Tide.HASH_Y, Tide.HASH_LAYER, Tide.HASH_MIX]:
		assert_string_contains(source, "%du" % multiplier)
	assert_string_contains(source, "0.65 * value_noise(relief_position, SWELL_SIZE, 1u)")
	assert_string_contains(source, "0.35 * value_noise(relief_position, HOLLOW_SIZE, 2u)")
	assert_eq(Tide.SWELL_SHARE, 0.65)
	assert_eq(Tide.HOLLOW_SHARE, 0.35)


func test_the_relief_gives_the_numbers_of_the_shader() -> void:
	# Worked out apart from the game with the shader's formulas.
	assert_almost_eq(Tide.relief_at(Vector2(0, 0)), 0.690565, 0.0001)
	assert_almost_eq(Tide.relief_at(Vector2(1000.5, -77.25)), 0.554273, 0.0001)
	assert_almost_eq(Tide.relief_at(Vector2(-8300, -960)), 0.385643, 0.0001)
	assert_almost_eq(Tide.relief_at(Vector2(123, 456)), 0.500749, 0.0001)


func test_the_relief_has_no_seams_between_cells() -> void:
	for edge in [Tide.HOLLOW_SIZE * 7.0, Tide.SWELL_SIZE * -3.0, Tide.SWELL_SIZE * 2.0]:
		var before := Tide.relief_at(Vector2(edge - 0.001, 33.0))
		var after := Tide.relief_at(Vector2(edge, 33.0))
		assert_almost_eq(before, after, 0.001, "at x = %s" % edge)


func test_tiles_flood_and_dry_with_the_tide() -> void:
	var tiles: Array[Vector2i] = []
	for y in range(-20, 20):
		for x in range(-20, 20):
			tiles.append(Vector2i(x, y))
	var flooded_at_low := 0
	var flooded_at_high := 0
	var was_flooded := {}
	for level in [0.0, 0.25, 0.5, 0.75, 1.0]:
		for tile in tiles:
			var is_flooded := Tide.floods(tile, level)
			# What the water covers stays covered while it rises.
			assert_true(is_flooded or not was_flooded.get(tile, false), "%s at %s" % [tile, level])
			was_flooded[tile] = is_flooded
			flooded_at_low += int(level == 0.0 and is_flooded)
			flooded_at_high += int(level == 1.0 and is_flooded)
	assert_lt(flooded_at_low, tiles.size() / 20, "little at low water")
	assert_eq(flooded_at_high, tiles.size(), "all at high water")


func test_a_tile_floods_when_the_water_covers_most_of_it() -> void:
	var tile := Vector2i(7, -3)
	var height := Tide.flood_height(tile)
	var origin := Vector2(tile) * WildlifeRules.TILE_SIZE
	var covered := 0
	var points := 0
	for y in 32:
		for x in 32:
			var relief := Tide.relief_at(origin + Vector2(x + 0.5, y + 0.5))
			covered += int(relief < height)
			points += 1
	assert_almost_eq(float(covered) / points, 0.5, 0.15, "about half is under at that level")
