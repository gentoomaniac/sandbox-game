extends SaveUpgradeCase
## The wear of desire paths is saved, and a save from before them (version 14) loads with none.


func test_the_wear_is_kept() -> void:
	var state := GameState.new_game(7)
	var tile := state.player.tile() + Vector2i(3, 3)
	state.world.set_terrain(tile, Tile.Terrain.GRASS)
	for _i in PathRules.default_rules().path_from():
		state.world.wear_tile(tile)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.world.to_dict()["wear"], state.world.to_dict()["wear"])


func test_a_version_14_save_loads_with_no_wear() -> void:
	var game := _current_game()
	game["world"].erase("wear")
	_write_save(14, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_eq(restored.world.to_dict()["wear"], [])
