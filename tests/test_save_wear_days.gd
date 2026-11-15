extends SaveUpgradeCase
## The wear of desire paths is saved, in days and in the steps of today (#61).


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
