extends SaveValidationCase
## The saved water of the can is checked against its range (task 122).


func test_water_in_the_can_beyond_the_can_is_refused() -> void:
	var game := _current_game()
	game["player"]["can_water"] = EnergyRules.default_rules().can_capacity() + 1
	assert_string_contains(_refusal_of(game).reason, "can_water")


func test_a_negative_or_part_litre_of_water_is_refused() -> void:
	var game := _current_game()
	game["player"]["can_water"] = -1
	assert_string_contains(_refusal_of(game).reason, "can_water")
	game["player"]["can_water"] = 2.5
	assert_string_contains(_refusal_of(game).reason, "can_water")
