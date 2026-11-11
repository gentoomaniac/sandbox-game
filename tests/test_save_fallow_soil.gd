extends SaveUpgradeCase
## The days tilled soil has lain fallow are saved (task 166), and a version 25 save loads with
## every tilled tile tended on the night of the load.

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


func test_a_version_25_save_loads_with_its_tilled_tiles_just_tended() -> void:
	var game: Dictionary = JSON.parse_string(JSON.stringify(_new_game().to_dict()))
	game["world"].erase("fallow_nights")
	game["world"].erase("fallow_soil")
	_write_save(25, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	var fallow := restored.world.fallow
	assert_eq(fallow.nights, 0)
	_pass_nights(restored, fallow.weedy_days - 1)
	assert_false(fallow.is_weedy(TILE))
	_pass_nights(restored, 1)
	assert_true(fallow.is_weedy(TILE))
	assert_true(fallow.is_weedy(OTHER_TILE))
