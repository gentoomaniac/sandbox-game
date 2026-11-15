extends SaveValidationCase
## The dead and half-dead trees are saved by their type, so no save version changed for them.


func test_a_world_with_snags_and_their_stumps_is_the_same_after_a_save_and_a_load() -> void:
	var state := GameState.new_game(7)
	var around := state.player.tile()
	var placed := {}
	for kind in WorldObjectSnags.KINDS:
		for type in [WorldObjectSnags.dead_type(kind), WorldObjectSnags.half_dead_type(kind)]:
			for y in range(-10, 10):
				var pos := around + Vector2i(2 + placed.size() * 2, y)
				if state.world.is_free_on(pos, Tile.Terrain.GRASS):
					state.world.add_object(WorldObject.new(type, pos))
					placed[pos] = type
					break
	assert_eq(placed.size(), 14, "room for them all")
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	# The save keeps the edits to the land: streaming the chunks in replays them.
	var generator := WorldGenerator.new(7)
	for coords in state.world.loaded_chunk_coords():
		restored.world.add_chunk(generator.generate_chunk(coords))
	for pos: Vector2i in placed:
		assert_eq(restored.world.object_at(pos).type, placed[pos])
