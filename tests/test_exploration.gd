extends SaveValidationCase
## The land the player has seen is explored for good, saved (version 50) and loaded.


func test_the_land_within_sight_is_explored_and_the_land_beyond_is_not() -> void:
	var explored := Exploration.new()

	explored.see(Vector2i(100, -40))

	assert_true(explored.is_explored(Vector2i(100, -40)))
	assert_true(explored.is_explored(Vector2i(100 + Exploration.SIGHT_RADIUS, -40)))
	assert_true(explored.is_explored(Vector2i(100, -40 - Exploration.SIGHT_RADIUS)))
	assert_false(explored.is_explored(Vector2i(100 + Exploration.SIGHT_RADIUS + 1, -40)))
	var corner := Vector2i.ONE * Exploration.SIGHT_RADIUS
	assert_false(explored.is_explored(Vector2i(100, -40) + corner), "the sight is round")


func test_walking_on_explores_the_land_behind_and_keeps_it() -> void:
	var state := GameState.new_game(7)
	var start := state.player.tile()

	PlayerRest.teleport_to(state, start + Vector2i(60, 0))

	assert_true(state.explored.is_explored(start))
	assert_true(state.explored.is_explored(start + Vector2i(60, 0)))
	assert_false(state.explored.is_explored(start + Vector2i(30, 0)))


func test_a_chunk_is_touched_when_its_edge_is_within_sight() -> void:
	var explored := Exploration.new()

	explored.see(Vector2i(2, 2))

	assert_true(explored.is_chunk_touched(Vector2i(-1, -1)))
	assert_false(explored.is_chunk_touched(Vector2i(2, 2)))


func test_a_chunk_is_full_when_every_tile_of_it_is_seen() -> void:
	var explored := Exploration.new()
	for y in range(-8, 40, 8):
		for x in range(-8, 40, 8):
			explored.see(Vector2i(x, y))

	assert_true(explored.is_chunk_full(Vector2i.ZERO))
	assert_false(explored.is_chunk_full(Vector2i(-1, -1)), "seen in part")
	assert_false(explored.is_chunk_full(Vector2i(5, 5)))


func test_the_mask_of_a_chunk_has_a_byte_a_tile() -> void:
	var explored := Exploration.new()
	explored.see(Vector2i(16, 16))

	var mask := explored.mask_of(Vector2i.ZERO)

	assert_eq(mask.size(), Exploration.TILES_PER_CHUNK)
	assert_eq(mask[16 * Chunk.CHUNK_SIZE + 16], 1)
	assert_eq(mask[0], 0)
	assert_eq(explored.mask_of(Vector2i(9, 9)).count(1), 0)


func test_the_revision_around_a_chunk_changes_when_land_beside_it_is_explored() -> void:
	var explored := Exploration.new()
	var before := explored.revision_around(Vector2i(1, 0))

	explored.see(Vector2i(2, 2))
	var after := explored.revision_around(Vector2i(1, 0))
	explored.see(Vector2i(2, 2))

	assert_ne(after, before)
	assert_eq(explored.revision_around(Vector2i(1, 0)), after, "nothing new seen")
	assert_eq(explored.revision_around(Vector2i(9, 9)), 0, "far off")


func test_the_explored_land_is_saved_and_loaded() -> void:
	var state := GameState.new_game(7)
	var far := state.player.tile() + Vector2i(-80, 45)
	state.explored.see(far)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH)

	assert_true(loaded.explored.is_explored(far + Vector2i(5, -5)))
	assert_true(loaded.explored.is_explored(state.player.tile()))
	assert_false(loaded.explored.is_explored(far + Vector2i(Exploration.SIGHT_RADIUS + 3, 0)))


func test_a_version_49_save_has_the_land_about_the_player_explored() -> void:
	var state := GameState.new_game(7)
	var game := _current_game()
	game.erase("explored")
	_write_save(49, game)

	var loaded := SaveFile.read(SAVE_PATH)

	assert_not_null(loaded)
	assert_true(loaded.explored.is_explored(state.player.tile()))
	assert_false(loaded.explored.is_explored(state.player.tile() + Vector2i(100, 0)))


func test_a_snapshot_does_not_change_when_the_player_walks_on() -> void:
	var explored := Exploration.new()
	explored.see(Vector2i.ZERO)
	var snapshot := explored.snapshot()

	explored.see(Vector2i(200, 0))

	assert_eq(Exploration.array_of(snapshot).size(), 4, "the four chunks about the origin")


func test_explored_land_of_a_chunk_outside_the_world_is_refused() -> void:
	var game := _current_game()
	var seen := Marshalls.raw_to_base64(PackedByteArray([0]))
	game["explored"] = [{"chunk": [900, 0], "seen": seen}]

	var problems: Array = _refusal_of(game).problems

	assert_eq(problems.size(), 2, str(problems))


func test_a_save_without_the_explored_land_is_refused() -> void:
	var game := _current_game()
	game.erase("explored")

	assert_true(_refusal_of(game).problems.has("no explored"))
