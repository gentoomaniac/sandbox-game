extends NpcCase
## What a trip does where the world is not loaded (off-screen travel is #68): it is searched over
## the masks; and the ends of a trip that is not walked: `place`, a door, a skip. Walking it there
## is in test_npc_far_walk.gd.

const SECONDS := 20


func _tile_at(x: int, y: int) -> Vector2i:
	return _middle + Vector2i(x, y)


func _centre_of(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


func _run(seconds: float) -> void:
	for _i in roundi(seconds / STEP_SECONDS):
		_step()


func _unload_chunk_of(tile: Vector2i) -> void:
	_world.remove_chunk(Chunk.world_to_chunk(tile))


## Lets frames go by, the masks made on their worker meanwhile, until the villager has its way (or
## is blocked): the trip is not searching any more.
func _run_until_searched(npc: Npc) -> void:
	for _i in 2000:
		if npc.trip.state != NpcTrip.State.SEARCHING:
			return
		_step()
		OS.delay_msec(2)
	fail_test("the search did not end")


## Lets frames go by, the masks of the ground it walks on made on their worker meanwhile, until the
## villager's trip is over.
func _run_until_arrived(npc: Npc) -> void:
	for _i in 2000:
		if not npc.is_travelling():
			return
		_step()
		OS.delay_msec(2)
	fail_test("the villager did not arrive")


## A tile of grass with nothing on it in a chunk of the generator, loaded or not.
func _free_tile_in(coords: Vector2i) -> Vector2i:
	var chunk := WorldGenerator.new(SEED).generate_chunk(coords)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var local := Vector2i(x, y)
			if chunk.terrain_at(local) == Tile.Terrain.GRASS and chunk.object_at(local) == null:
				return Chunk.to_world(coords, local)
	fail_test("no free tile in %s" % coords)
	return Vector2i.ZERO


func test_an_unloaded_villager_searches_over_the_masks_and_walks_there() -> void:
	watch_signals(_npcs)
	var npc := _add_villager(_centre_of(_tile_at(0, 0)), _yard_middle())
	_unload_chunk_of(_tile_at(0, 0))
	_npcs.walk_to(npc, _tile_at(3, 3), _world)
	_run_until_searched(npc)
	assert_eq(npc.trip.searches, 1)
	assert_eq(npc.trip.state, NpcTrip.State.WALKING, "it has its way")
	assert_gt(npc.trip.path.size(), 0)
	assert_signal_emit_count(_npcs, "trip_blocked", 0)
	_run_until_arrived(npc)
	assert_signal_emit_count(_npcs, "trip_arrived", 1)
	assert_eq(npc.tile(), _tile_at(3, 3))


func test_a_goal_that_is_not_loaded_is_searched_for_and_no_trip_is_told_it_is_not_loaded() -> void:
	watch_signals(_npcs)
	var npc := _add_villager(_centre_of(_tile_at(0, 0)), _yard_middle())
	var goal_chunk := Chunk.world_to_chunk(_middle) + Vector2i(8, 0)
	assert_false(_world.is_chunk_loaded(goal_chunk))
	_npcs.walk_to(npc, _free_tile_in(goal_chunk), _world)
	_run_until_searched(npc)
	assert_eq(npc.trip.searches, 1)
	assert_gt(npc.trip.nodes_looked_at, 0, "it looked all over the yard, which the sea rings")
	assert_signal_emitted_with_parameters(_npcs, "trip_blocked", [npc, NpcTrip.Block.NO_WAY])
	assert_false(NpcTrip.Block.has("NOT_LOADED"))


func test_a_villager_in_an_unloaded_chunk_is_placed_but_one_in_a_loaded_chunk_never() -> void:
	var seen := _add_villager(_centre_of(_tile_at(0, 0)), _yard_middle())
	var at := seen.position
	assert_false(_npcs.place(seen, _tile_at(4, 4), _world))
	assert_eq(seen.position, at)
	var far := _add_villager(_centre_of(_tile_at(1, 1)), _yard_middle())
	_npcs.walk_to(far, _tile_at(5, 5), _world)
	_unload_chunk_of(far.tile())
	_unload_chunk_of(_tile_at(4, 4))
	assert_true(_npcs.place(far, _tile_at(4, 4), _world))
	assert_eq(far.position, _centre_of(_tile_at(4, 4)))
	assert_false(far.is_travelling())


func test_a_villager_is_sent_to_the_yard_in_front_of_a_door() -> void:
	watch_signals(_npcs)
	var house := _world.place_building(BuildingTypes.SHACK, _tile_at(2, -8))
	assert_not_null(house)
	var npc := _add_villager(_centre_of(_tile_at(-6, 6)), _yard_middle())
	_npcs.walk_to_door(npc, house, _world)
	_run(SECONDS)
	assert_signal_emit_count(_npcs, "trip_arrived", 1)
	assert_eq(npc.tile(), house.door_tile() + Vector2i.DOWN)


func test_the_minutes_of_a_skip_that_are_walked_look_for_no_way() -> void:
	var npc := _add_villager(_centre_of(_tile_at(-6, -5)), _yard_middle())
	_npcs.walk_to(npc, _tile_at(6, -5), _world)
	for _i in 100:
		_npcs.update(STEP_SECONDS, _world, _state.player.position, _state.clock, true, false)
	assert_eq(npc.trip.search.nodes_looked_at, 0)
	assert_eq(npc.trip.state, NpcTrip.State.SEARCHING)


func test_a_villager_is_not_placed_in_a_loaded_chunk_even_from_an_unloaded_one() -> void:
	var far := _add_villager(_centre_of(_tile_at(1, 1)), _yard_middle())
	_unload_chunk_of(far.tile())
	var at := far.position
	var chunks := _world.loaded_chunk_coords()
	var loaded_tile := Chunk.to_world(chunks[0], Vector2i(5, 5))
	assert_true(_world.is_chunk_loaded(Chunk.world_to_chunk(loaded_tile)))
	assert_false(_npcs.place(far, loaded_tile, _world))
	assert_eq(far.position, at)
