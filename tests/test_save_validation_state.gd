extends SaveValidationCase
## The state of an item stack (a candle's burn) is checked on a save.


func test_a_state_on_a_stack_of_two_or_that_is_no_dictionary_is_refused() -> void:
	var game := _current_game()
	_slots(game)[1] = {"item": "logs", "count": 2, "state": {"burnt_minutes": 5}}
	_slots(game)[2] = {"item": "logs", "count": 1, "state": 5}

	var result := _refusal_of(game)

	assert_string_contains(result.reason, "slot 1: a state belongs to one item")
	assert_string_contains(result.reason, "slot 2: a state belongs to one item")
