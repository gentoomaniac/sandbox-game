extends SaveUpgradeCase
## Version 42 counted the wear of desire paths in steps; a save of it keeps the look of every worn
## tile, now in days of wear (#61).


func _load_version_42(wear: Array) -> World:
	var game := _current_game()
	game["world"]["wear"] = wear
	game["world"].erase("wear_today")
	_write_save(42, game)
	return SaveFile.read(SAVE_PATH).world


func test_a_tile_keeps_the_look_its_steps_gave_it() -> void:
	var world := _load_version_42(
		[[3, 4, 7.0], [5, 6, 8.0], [7, 8, 23.5], [9, 10, 24.0], [11, 12, 32.0]]
	)

	assert_eq(world.wear_stage(Vector2i(3, 4)), PathRules.Stage.UNWORN, "7 steps")
	assert_eq(world.wear_stage(Vector2i(5, 6)), PathRules.Stage.TRODDEN, "8 steps")
	assert_eq(world.wear_stage(Vector2i(7, 8)), PathRules.Stage.TRODDEN, "23.5 steps")
	assert_eq(world.wear_stage(Vector2i(9, 10)), PathRules.Stage.PATH, "24 steps")
	assert_eq(world.wear_stage(Vector2i(11, 12)), PathRules.Stage.PATH, "32 steps")


func test_no_tile_has_taken_steps_today() -> void:
	var world := _load_version_42([[5, 6, 8.0]])

	assert_eq(world.wear_steps(), {})


func test_a_current_save_keeps_days_and_steps() -> void:
	var state := GameState.new_game(7)
	var tile := state.player.tile() + Vector2i(3, 3)
	state.world.set_terrain(tile, Tile.Terrain.GRASS)
	state.world.set_wear_days(tile, 5)
	state.world.wear_tile(tile + Vector2i.RIGHT, 2.5)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH).world

	assert_eq(restored.wear_days(), {tile: 5})
	assert_eq(restored.wear_steps(), {tile + Vector2i.RIGHT: 2.5})


func test_a_damaged_entry_of_wear_is_refused() -> void:
	for key in ["wear", "wear_today"]:
		var game := _current_game()
		game["world"][key] = [[1, 2, "a lot"]]
		_write_save(SaveFile.VERSION, game)

		assert_eq(SaveFile.load_game(SAVE_PATH).outcome, LoadResult.Outcome.REFUSED, key)


func test_a_part_of_a_day_of_wear_is_refused() -> void:
	var game := _current_game()
	game["world"]["wear"] = [[1, 2, 2.5]]
	_write_save(SaveFile.VERSION, game)

	assert_eq(SaveFile.load_game(SAVE_PATH).outcome, LoadResult.Outcome.REFUSED)
