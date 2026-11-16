extends SaveUpgradeCase
## The grids of the kiln and the oven and their runs are saved (task 199).


## The object on a tile of a loaded game, its chunk loaded first.
func _object_at(state: GameState, pos: Vector2i) -> WorldObject:
	var coords := Chunk.world_to_chunk(pos)
	if not state.world.is_chunk_loaded(coords):
		state.world.add_chunk(WorldGenerator.new(state.world.world_seed).generate_chunk(coords))
	return state.world.object_at(pos)


func test_a_loaded_kiln_is_kept() -> void:
	var state := GameFactory.new_game(7)
	var kiln := WorldObject.new(WorldObjectTypes.KILN, Vector2i(3, 4))
	kiln.storage.add(ItemTypes.RAW_BRICK, 12)
	state.world.add_object(kiln)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(_object_at(restored, Vector2i(3, 4)).storage.totals(), {ItemTypes.RAW_BRICK: 12})
