extends SaveValidationCase
## The purse is saved with the player (#49); a save of version 53 has none and gets the start
## purse; the validator wants a whole number from 0.


func test_a_saved_purse_is_loaded() -> void:
	var state := GameState.new_game(7)
	state.player.purse.schilling = 77
	assert_true(SaveFile.write(state, SAVE_PATH))

	assert_eq(SaveFile.read(SAVE_PATH).player.purse.schilling, 77)


func test_a_version_53_save_gets_the_start_purse() -> void:
	var game := _current_game()
	game["player"].erase("money")
	_write_save(53, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_eq(restored.player.purse.schilling, 32)


func test_a_missing_negative_or_part_purse_is_refused() -> void:
	var game := _current_game()
	game["player"].erase("money")
	assert_string_contains(_refusal_of(game).reason, "money")
	game["player"]["money"] = -1
	assert_string_contains(_refusal_of(game).reason, "money")
	game["player"]["money"] = 2.5
	assert_string_contains(_refusal_of(game).reason, "money")
