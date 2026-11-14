extends SaveValidationCase
## The wood and the flame of a campfire are saved with it (version 41, task 56). A fireplace of an
## older save burns on with 4 logs; a log left that is not a whole number of minutes up to a log's
## burn is refused.


func _fireplace(state: Dictionary) -> Dictionary:
	return {"type": "fireplace", "pos": [3, 4], "state": state, "storage": [null]}


func test_a_version_40_save_lights_its_fireplace_with_four_logs() -> void:
	var game := _current_game()
	_with_object_edit(game, _fireplace({}))
	_write_save(40, game)

	var restored := SaveFile.read(SAVE_PATH)

	var coords := Chunk.world_to_chunk(Vector2i(3, 4))
	restored.world.add_chunk(WorldGenerator.new(7).generate_chunk(coords))
	var fire := restored.world.object_at(Vector2i(3, 4))
	assert_false(Campfire.is_out(fire))
	assert_eq(Campfire.minutes_left(fire), 4 * 180)


func test_a_log_left_that_is_negative_too_long_or_not_whole_is_refused() -> void:
	var game := _current_game()
	_with_object_edit(game, _fireplace({"lit": true, "log_left": -5}))
	assert_string_contains(_refusal_of(game).reason, "log_left -5.0 is not between 0 and 180")
	game = _current_game()
	_with_object_edit(game, _fireplace({"lit": true, "log_left": 999}))
	assert_string_contains(_refusal_of(game).reason, "log_left 999.0 is not between 0 and 180")
	game = _current_game()
	_with_object_edit(game, _fireplace({"lit": true, "log_left": 12.5}))
	assert_string_contains(_refusal_of(game).reason, "log_left should be a whole number")
	game = _current_game()
	_with_object_edit(game, _fireplace({"lit": 1, "log_left": 5}))
	assert_string_contains(_refusal_of(game).reason, "lit should be true or false")
	game = _current_game()
	_with_object_edit(game, _fireplace({"lit": true}))
	assert_string_contains(_refusal_of(game).reason, "a lit fire needs log_left")
