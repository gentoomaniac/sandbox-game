extends SaveUpgradeCase
## Version 31 saves keep the grids of the kiln and the oven and their runs (task 199). A version 30
## save gives every kiln and oven an empty grid, in the world and in a house, and a kiln that was
## firing keeps firing: its old load in the grid, its bricks to come at the same minute.


func _version_30_object(type: String, pos: Array, work: Variant = null) -> Dictionary:
	return {"type": type, "pos": pos, "state": {} if work == null else {"work": work}}


func _with_version_30_kilns(game: Dictionary, work: Variant = null) -> void:
	game["world"]["object_edits"].append(
		{"pos": [3, 4], "object": _version_30_object("kiln", [3, 4], work)}
	)
	game["world"]["object_edits"].append(
		{"pos": [5, 4], "object": _version_30_object("oven", [5, 4])}
	)


## The object on a tile of a loaded game, its chunk loaded first.
func _object_at(state: GameState, pos: Vector2i) -> WorldObject:
	var coords := Chunk.world_to_chunk(pos)
	if not state.world.is_chunk_loaded(coords):
		state.world.add_chunk(WorldGenerator.new(state.world.world_seed).generate_chunk(coords))
	return state.world.object_at(pos)


func test_a_loaded_kiln_is_kept() -> void:
	var state := GameState.new_game(7)
	var kiln := WorldObject.new(WorldObjectTypes.KILN, Vector2i(3, 4))
	kiln.storage.add(ItemTypes.RAW_BRICK, 12)
	state.world.add_object(kiln)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(_object_at(restored, Vector2i(3, 4)).storage.totals(), {ItemTypes.RAW_BRICK: 12})


func test_a_version_30_kiln_and_oven_get_empty_grids() -> void:
	var game := _current_game()
	_with_version_30_kilns(game)
	_write_save(30, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	for pos in [Vector2i(3, 4), Vector2i(5, 4)]:
		var object := _object_at(restored, pos)
		assert_eq(object.storage.slots.size(), 9)
		assert_true(object.storage.is_empty())


func test_a_version_30_firing_goes_on_with_its_load_and_its_bricks() -> void:
	var game := _current_game()
	_with_version_30_kilns(game, {"recipe": "bricks_large", "done_minute": 2000})
	_write_save(30, game)

	var restored := SaveFile.read(SAVE_PATH)

	var kiln := _object_at(restored, Vector2i(3, 4))
	assert_eq(kiln.storage.totals(), {ItemTypes.RAW_BRICK: 12, ItemTypes.LOGS: 3})
	assert_false(kiln.state.has("work"))
	var run: Dictionary = kiln.state[ProcessStation.RUN]
	assert_eq(run["recipe"], "bricks")
	assert_eq(int(run["done_minute"]), 2000)
	assert_eq(int(run["start_minute"]), 2000 - 12 * GameClock.MINUTES_PER_HOUR)
	ProcessStation.settle(kiln, 2000)
	assert_eq(kiln.storage.totals(), {ItemTypes.BRICK: 12})
