extends SaveUpgradeCase
## The clock of a save.


func test_a_current_save_keeps_its_day() -> void:
	var state := GameState.new_game(7)
	state.clock.day = 130
	assert_true(SaveFile.write(state, SAVE_PATH))

	assert_eq(SaveFile.read(SAVE_PATH).clock.day, 130)
