extends SaveValidationCase
## The height and strength of a dyke the game changed are saved with its object, among the edits of
## the world (#103); a save of version 54 has none, and the validator wants whole numbers in range.


func _dyke_save(height_cm: Variant, strength_pct: Variant) -> Dictionary:
	var data := _current_game()
	_with_object_edit(
		data,
		{
			"type": "dyke",
			"pos": [3, 4],
			"state": {"height_cm": height_cm, "strength_pct": strength_pct},
		}
	)
	return data


func test_a_changed_dyke_is_saved_and_loaded() -> void:
	var state := GameFactory.new_game(7)
	var tile := state.player.tile() + Vector2i(3, 0)
	state.world.remove_object(tile)
	var dyke := WorldObject.new(WorldObjectTypes.DYKE, tile)
	state.world.add_object(dyke)
	state.world.dykes.change(state.world, dyke, 0.8, 0.3)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	var coords := Chunk.world_to_chunk(tile)
	if not restored.world.is_chunk_loaded(coords):
		restored.world.add_chunk(WorldGenerator.new(7).generate_chunk(coords))
	var loaded := restored.world.object_at(tile)
	assert_almost_eq(restored.world.dykes.height_of(loaded), 0.8, 0.001)
	assert_almost_eq(restored.world.dykes.strength_of(loaded), 0.3, 0.001)


func test_a_version_54_save_loads_with_the_dykes_as_generated() -> void:
	_write_save(54, _current_game())

	assert_not_null(SaveFile.read(SAVE_PATH))


func test_a_dyke_with_values_in_range_is_accepted() -> void:
	_write_save(SaveFile.VERSION, _dyke_save(360, 100))

	assert_not_null(SaveFile.read(SAVE_PATH))


func test_a_dyke_with_a_height_or_strength_out_of_range_or_not_whole_is_refused() -> void:
	assert_string_contains(_refusal_of(_dyke_save(-1, 50)).reason, "height_cm")
	assert_string_contains(_refusal_of(_dyke_save(401, 50)).reason, "height_cm")
	assert_string_contains(_refusal_of(_dyke_save(100, 101)).reason, "strength_pct")
	assert_string_contains(_refusal_of(_dyke_save(100, 2.5)).reason, "strength_pct")
