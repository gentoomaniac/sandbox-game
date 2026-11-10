extends SaveUpgradeCase
## The wear of desire paths is saved.


func test_the_wear_is_kept() -> void:
	var state := GameState.new_game(7)
	var tile := state.player.tile() + Vector2i(3, 3)
	state.world.set_terrain(tile, Tile.Terrain.GRASS)
	for _i in PathRules.default_rules().path_from():
		state.world.wear_tile(tile)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.world.to_dict()["wear"], state.world.to_dict()["wear"])
