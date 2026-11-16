extends ResourceCase
## The height and strength of the generated dykes (storm surge, #103), and the hover over one.

const COAST_ROWS := 400

var _generator := WorldGenerator.new(SEED)
var _profile := DykeProfile.new(SEED, _generator)


func _sea_dyke_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in COAST_ROWS:
		var tile := Vector2i(_generator.first_land_x(y), y)
		if _generator.object_type_at(tile, _generator.terrain_at(tile)) == WorldObjectTypes.DYKE:
			tiles.append(tile)
	return tiles


func test_the_values_are_the_same_for_the_same_seed() -> void:
	var tile := _sea_dyke_tiles()[0]
	var again := DykeProfile.new(SEED, WorldGenerator.new(SEED))
	assert_eq(_profile.height_at(tile), again.height_at(tile))
	assert_eq(_profile.strength_at(tile), again.strength_at(tile))


func test_the_sea_dyke_stays_within_its_spread_and_some_stretches_are_low() -> void:
	var tiles := _sea_dyke_tiles()
	assert_gt(tiles.size(), COAST_ROWS / 2, "the sea dyke runs along the coast")
	var lowest := INF
	var highest := -INF
	for tile in tiles:
		assert_true(_profile.is_sea_dyke(tile))
		lowest = minf(lowest, _profile.height_at(tile))
		highest = maxf(highest, _profile.height_at(tile))
	assert_between(lowest, 1.6, 3.2)
	assert_between(highest, 1.6, 3.2)
	assert_lt(lowest, 2.4, "a stretch is low, where a surge can come through")


func test_a_stretch_of_dyke_shares_one_height() -> void:
	var tile := _sea_dyke_tiles()[0]
	var next := tile + Vector2i(0, 1)
	assert_almost_eq(_profile.height_at(tile), _profile.height_at(next), 0.1)


func test_the_strength_is_between_nothing_and_one() -> void:
	for tile in _sea_dyke_tiles():
		assert_between(_profile.strength_at(tile), 0.0, 1.0)


func test_river_dykes_are_lower_than_the_sea_dyke() -> void:
	var far_inland := Vector2i(300, 0)
	assert_false(_profile.is_sea_dyke(far_inland))
	assert_lt(_profile.height_at(far_inland), 1.4)


func test_the_words_name_the_height_and_the_turf() -> void:
	assert_eq(_profile.words(2.1, 0.8), "Dyke, 2.1 m, well turfed")
	assert_eq(_profile.words(1.2, 0.5), "Dyke, low, 1.2 m, turfed")
	assert_eq(_profile.words(3.0, 0.1), "Dyke, high, 3.0 m, bare")


func test_the_hover_over_a_dyke_gives_its_height_and_turf() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.DYKE, _tile))
	var expected := _world.dykes.words(
		_world.dykes.height_at(_tile), _world.dykes.strength_at(_tile)
	)
	assert_eq(WorldHoverText.object_text_at(_state, _tile), expected)
	assert_true(expected.begins_with("Dyke, "))
