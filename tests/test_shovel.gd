extends GutTest
## Clay spots and the shovel: where the spots are, the odds of digging clay, the spent spot and
## saving.

const SEED := 42
## The area searched for clay spots: it holds the river and wetland.
const SEARCH_AREA := Rect2i(0, -170, 96, 340)
const SPOTS_TO_DIG := 120
const MIDSUMMER := 45

var _generator := WorldGenerator.new(SEED)
var _state: GameState
var _spots: Array[Vector2i]


func before_all() -> void:
	_spots = _find_spots(SPOTS_TO_DIG)


func before_each() -> void:
	_state = GameState.new_game(SEED)
	_state.clock.day = MIDSUMMER
	_load_chunks_of(_state, _spots)


func _find_spots(limit: int) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for y in range(SEARCH_AREA.position.y, SEARCH_AREA.end.y):
		for x in range(SEARCH_AREA.position.x, SEARCH_AREA.end.x):
			if _generator.is_clay_spot(Vector2i(x, y)):
				spots.append(Vector2i(x, y))
				if spots.size() == limit:
					return spots
	return spots


func _load_chunks_of(state: GameState, tiles: Array[Vector2i]) -> void:
	for tile in tiles:
		var coords := Chunk.world_to_chunk(tile)
		if not state.world.is_chunk_loaded(coords):
			state.world.add_chunk(_generator.generate_chunk(coords))


func _is_wet_within_reach(pos: Vector2i) -> bool:
	var reach := WorldGenerator.CLAY_REACH
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var terrain := _generator.terrain_at(pos + Vector2i(x, y))
			if terrain == Tile.Terrain.WATER or terrain == Tile.Terrain.WETLAND:
				return true
	return false


## Digs every spot with the shovel on `day`; returns whether each gave clay.
func _dig_all(state: GameState, day: int) -> Array[bool]:
	state.clock.day = day
	state.player.inventory.select(_shovel_slot(state))
	var gave_clay: Array[bool] = []
	for spot in _spots:
		var before := state.world.ground_count_of(ItemTypes.CLAY)
		state.use_tile(spot)
		gave_clay.append(state.world.ground_count_of(ItemTypes.CLAY) > before)
	return gave_clay


func _shovel_slot(state: GameState) -> int:
	for slot in Inventory.HOTBAR_SIZE:
		if state.player.inventory.item_in(slot) == ItemTypes.SHOVEL:
			return slot
	fail_test("no shovel")
	return 0


func _hold_shovel() -> void:
	_state.player.inventory.select(_shovel_slot(_state))


# --- Where the spots are ---


func test_clay_spots_are_grass_with_water_or_wetland_within_reach() -> void:
	assert_eq(_spots.size(), SPOTS_TO_DIG, "the search area has enough spots")
	for spot in _spots:
		assert_eq(_generator.terrain_at(spot), Tile.Terrain.GRASS)
		assert_true(_is_wet_within_reach(spot), "water near %s" % spot)


## The first row of water in a column: the river runs west to east.
func _river_row(x: int) -> int:
	for y in range(SEARCH_AREA.position.y, SEARCH_AREA.end.y):
		if _generator.terrain_at(Vector2i(x, y)) == Tile.Terrain.WATER:
			return y
	fail_test("no river at x = %d" % x)
	return 0


func test_there_are_no_clay_spots_far_from_water() -> void:
	var dry_tiles_checked := 0
	for x in range(100, 164, 4):
		for y in range(_river_row(x) + 12, _river_row(x) + 40):
			var pos := Vector2i(x, y)
			if not _is_wet_within_reach(pos):
				dry_tiles_checked += 1
				assert_false(_generator.is_clay_spot(pos), "%s is far from water" % pos)
	assert_gt(dry_tiles_checked, 100)


func test_clay_spots_cluster_and_are_a_small_share_of_the_land_near_water() -> void:
	var near_water := 0
	var spots := 0
	for x in range(0, 48):
		for y in range(_river_row(x) - 14, _river_row(x) + 15):
			var pos := Vector2i(x, y)
			if _generator.terrain_at(pos) == Tile.Terrain.GRASS and _is_wet_within_reach(pos):
				near_water += 1
				spots += 1 if _generator.is_clay_spot(pos) else 0
	assert_gt(near_water, 100)
	assert_between(float(spots) / near_water, 0.02, 0.3)


func test_clay_spots_are_the_same_for_the_same_seed() -> void:
	var other := WorldGenerator.new(SEED)
	for spot in _spots.slice(0, 20):
		assert_true(other.is_clay_spot(spot))


func test_no_clay_spot_lies_under_an_object() -> void:
	for spot in _spots:
		assert_eq(_generator.object_type_at(spot, Tile.Terrain.GRASS), &"", "%s" % spot)


# --- Digging ---


func test_the_shovel_is_usable_on_any_free_grass_and_nowhere_else() -> void:
	_hold_shovel()
	var spot := _spots[0]
	var elsewhere := _grass_tile_without_clay()
	assert_eq(_state.use_at(spot), GameState.Use.DIG)
	assert_eq(_state.use_at(elsewhere), GameState.Use.DIG, "the cursor can't tell the spot")
	var tilled := _grass_tile_without_clay(elsewhere)
	_state.world.set_terrain(tilled, Tile.Terrain.SOIL)
	assert_eq(_state.use_at(tilled), GameState.Use.NOTHING)
	_state.world.add_object(WorldObject.new(WorldObjectTypes.OAK, spot + Vector2i.UP))
	assert_eq(_state.use_at(spot + Vector2i.UP), GameState.Use.NOTHING)


func _grass_tile_without_clay(not_this := Vector2i.ZERO) -> Vector2i:
	for y in range(-6, 6):
		for x in range(-6, 6):
			var pos := _state.player.tile() + Vector2i(x, y)
			if pos != not_this and _state.world.is_free_on(pos, Tile.Terrain.GRASS):
				if not _state.world.has_clay(pos):
					return pos
	fail_test("no grass near the camp")
	return Vector2i.ZERO


func test_digging_a_clay_spot_gives_clay_about_four_times_in_ten() -> void:
	var gave_clay := _dig_all(_state, MIDSUMMER)
	var clay_spots := gave_clay.count(true)
	assert_between(float(clay_spots) / _spots.size(), 0.28, 0.52)
	assert_eq(_state.world.ground_count_of(ItemTypes.CLAY), 2 * clay_spots)


func test_the_roll_is_the_same_for_the_same_spot_and_day_and_differs_between_days() -> void:
	var first := _dig_all(_state, MIDSUMMER)
	var other_game := GameState.new_game(SEED)
	_load_chunks_of(other_game, _spots)
	assert_eq(_dig_all(other_game, MIDSUMMER), first, "same day, same result")
	var later_game := GameState.new_game(SEED)
	_load_chunks_of(later_game, _spots)
	assert_ne(_dig_all(later_game, MIDSUMMER + 1), first, "the day is part of the roll")


func test_a_dug_spot_is_spent_whether_or_not_it_gave_clay() -> void:
	_dig_all(_state, MIDSUMMER)
	for spot in _spots:
		assert_false(_state.world.has_clay(spot), "%s is spent" % spot)
	var clay_before := _state.world.ground_count_of(ItemTypes.CLAY)
	_dig_all(_state, MIDSUMMER + 1)
	assert_eq(_state.world.ground_count_of(ItemTypes.CLAY), clay_before, "nothing more to find")


func test_a_spent_spot_recovers_over_nights() -> void:
	var spot := _spots[0]
	_hold_shovel()
	_state.use_tile(spot)
	for night in World.CLAY_SPENT_NIGHTS - 1:
		_state.clock.advance(GameClock.MINUTES_PER_DAY)
		assert_false(_state.world.has_clay(spot), "night %d" % (night + 1))
	_state.clock.advance(GameClock.MINUTES_PER_DAY)
	assert_true(_state.world.has_clay(spot))


func test_digging_elsewhere_gives_nothing_and_spends_nothing() -> void:
	_hold_shovel()
	var elsewhere := _grass_tile_without_clay()
	for day in range(MIDSUMMER, MIDSUMMER + 30):
		_state.clock.day = day
		assert_eq(_state.use_tile(elsewhere), GameState.Use.DIG)
	assert_eq(_state.world.ground_count_of(ItemTypes.CLAY), 0)
	assert_lt(_state.player.energy, PlayerState.MAX_ENERGY, "digging still costs energy")


# --- Saving ---


func test_a_spent_spot_stays_spent_through_the_save() -> void:
	var spot := _spots[0]
	_hold_shovel()
	_state.use_tile(spot)
	_state.clock.advance(GameClock.MINUTES_PER_DAY)
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	_load_chunks_of(restored, _spots)
	assert_false(restored.world.has_clay(spot))
	for night in World.CLAY_SPENT_NIGHTS - 1:
		restored.clock.advance(GameClock.MINUTES_PER_DAY)
	assert_true(restored.world.has_clay(spot), "it recovers on schedule")


# --- The hint ---


func test_a_clay_spot_shows_a_faint_hint_until_it_is_dug() -> void:
	var view := WorldView.new()
	add_child_autofree(view)
	view.show_world(_state.world)
	var spot := _spots[0]
	view._draw_decoration(spot, TerrainTileset.Layer.GRASS)
	assert_eq(view._clay_hints.get_cell_source_id(spot), TerrainTileset.CLAY_HINT_SOURCE_ID)
	_hold_shovel()
	_state.use_tile(spot)
	assert_eq(view._clay_hints.get_cell_source_id(spot), -1, "a spent spot shows nothing")
	var elsewhere := _grass_tile_without_clay()
	view._draw_decoration(elsewhere, TerrainTileset.Layer.GRASS)
	assert_eq(view._clay_hints.get_cell_source_id(elsewhere), -1)
