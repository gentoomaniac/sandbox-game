extends SaveValidationCase
## The saved water of the can, the needs of the animals and the stock of a trough are checked
## against their ranges (task 122).


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


func _reason_of_object_with(type: String, state: Dictionary) -> String:
	var game := _current_game()
	_with_object_edit(game, {"type": type, "pos": [3, 4], "state": state})
	return _refusal_of(game).reason


func test_a_need_outside_zero_to_one_is_refused() -> void:
	for need in ["hunger", "thirst"]:
		for bad in [-0.1, 1.5]:
			var game := _current_game()
			var cow := FarmAnimal.new(LivestockRules.COW, &"angler", Vector2(2.5, 3.5)).to_dict()
			cow[need] = bad
			game["livestock"] = [cow]
			assert_string_contains(_refusal_of(game).reason, need)


func test_a_stock_beyond_the_capacity_or_not_whole_is_refused() -> void:
	assert_string_contains(_reason_of_object_with("trough", {"stock": 101}), "stock")
	assert_string_contains(_reason_of_object_with("hay_rack", {"stock": -1}), "stock")
	assert_string_contains(_reason_of_object_with("trough", {"stock": 5.5}), "stock")


func test_a_stock_that_is_no_number_is_refused_not_compared() -> void:
	assert_string_contains(_reason_of_object_with("trough", {"stock": "broken"}), "stock")


func test_a_full_stock_is_fine() -> void:
	var game := _current_game()
	_with_object_edit(game, {"type": "trough", "pos": [3, 4], "state": {"stock": 100}})
	_write_save(SaveFile.VERSION, game)
	assert_eq(SaveFile.load_game(SAVE_PATH).outcome, LoadResult.Outcome.READY)
