extends SaveValidationCase
## The attribute levels are saved (version 30); a save of version 29, which had none, loads with
## the base levels; a level outside the rules is refused.


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


func test_a_version_29_save_loads_with_the_base_levels() -> void:
	var game := _current_game()
	game["player"].erase("attributes")
	_write_save(29, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.attributes.max_energy(), 100.0)
	assert_eq(restored.player.attributes.max_health(), 100.0)
	assert_eq(restored.player.attributes.carry_capacity(), 40.0)


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
