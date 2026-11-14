extends SaveValidationCase
## The attribute levels are saved (version 30); a level outside the rules is refused.


func test_the_levels_are_kept_and_the_bonuses_are_not() -> void:
	var state := GameState.new_game(7)
	state.player.attributes.set_level(Attributes.STRENGTH, 14)
	state.player.attributes.set_level(Attributes.HP, 3)
	state.player.attributes.add_bonus(&"stew", Attributes.STRENGTH, 2)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.attributes.level(Attributes.STRENGTH), 14)
	assert_eq(restored.player.attributes.level(Attributes.HP), 3)
	assert_eq(restored.player.attributes.bonus(Attributes.STRENGTH), 0)


func test_a_level_out_of_range_is_refused_with_its_place() -> void:
	var game := _current_game()
	game["player"]["attributes"]["levels"]["strength"] = 0
	var result := _refusal_of(game)
	assert_string_contains(result.reason, "player attributes levels")
	assert_string_contains(result.reason, "strength")


func test_a_missing_level_is_refused() -> void:
	var game := _current_game()
	game["player"]["attributes"]["levels"].erase("agility")
	var result := _refusal_of(game)
	assert_string_contains(result.reason, "agility")
