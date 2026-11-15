extends SaveUpgradeCase
## The wear of desire paths, and the steps taken today, are saved.


func test_the_wear_is_kept() -> void:
	var state := GameState.new_game(7)
	var tile := state.player.tile() + Vector2i(3, 3)
	state.world.set_terrain(tile, Tile.Terrain.GRASS)
	state.world.set_wear_days(tile, PathRules.default_rules().path_after_days())
	state.world.wear_tile(tile + Vector2i.RIGHT, 4.5)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.world.to_dict()["wear"], state.world.to_dict()["wear"])
	assert_eq(restored.world.to_dict()["wear_today"], state.world.to_dict()["wear_today"])
	assert_eq(restored.world.wear_stage(tile), PathRules.Stage.PATH)
	assert_eq(restored.world.wear_steps(), {tile + Vector2i.RIGHT: 4.5})
