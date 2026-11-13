extends SaveUpgradeCase
## The days tilled soil has lain fallow are saved (task 166).

const TILE := Vector2i(3, 4)
const OTHER_TILE := Vector2i(5, 4)


func _new_game() -> GameState:
	var state := GameState.new_game(7)
	for tile in [TILE, OTHER_TILE]:
		state.world.set_terrain(tile, Tile.Terrain.SOIL)
	return state


func _pass_nights(state: GameState, count: int) -> void:
	for _night in count:
		state.simulation.advance(state.clock.minutes_until(0))


func test_the_days_of_lying_fallow_are_kept() -> void:
	var state := _new_game()
	var weedy_days := state.world.fallow.weedy_days
	_pass_nights(state, weedy_days - 1)
	state.world.set_moisture(OTHER_TILE, 1.0)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)
	_pass_nights(restored, 1)

	assert_true(restored.world.fallow.is_weedy(TILE))
	assert_false(restored.world.fallow.is_weedy(OTHER_TILE), "watered a day before the save")
	assert_eq(restored.world.to_dict()["fallow_soil"], state.world.to_dict()["fallow_soil"])
