extends NpcCase
## What a trip does where the world is not loaded (off-screen travel is #68): the villager
## stands, blocked as NOT_LOADED, and looks again when chunks have loaded; and the ends of a trip
## that is not walked: `place`, a door, a skip.

const SECONDS := 20
const NOT_LOADED := NpcTrip.Block.NOT_LOADED


func _tile_at(x: int, y: int) -> Vector2i:
	return _middle + Vector2i(x, y)


func _centre_of(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


func _run(seconds: float) -> void:
	for _i in roundi(seconds / STEP_SECONDS):
		_step()


func _unload_chunk_of(tile: Vector2i) -> void:
	_world.remove_chunk(Chunk.world_to_chunk(tile))


func _load_chunk_of(tile: Vector2i) -> void:
	var coords := Chunk.world_to_chunk(tile)
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))


func test_an_unloaded_villager_is_blocked_without_a_search_and_walks_when_loaded() -> void:
	watch_signals(_npcs)
	var npc := _add_villager(_centre_of(_tile_at(0, 0)), _yard_middle())
	_unload_chunk_of(_tile_at(0, 0))
	_npcs.walk_to(npc, _tile_at(3, 3), _world)
	_run(SECONDS)
	assert_signal_emit_count(_npcs, "trip_blocked", 1)
	assert_signal_emitted_with_parameters(_npcs, "trip_blocked", [npc, NOT_LOADED])
	assert_eq(npc.trip.searches, 0, "nothing is searched where nothing is there")
	_load_chunk_of(_tile_at(0, 0))
	_run(_npcs.rules.travel("blocked_min_seconds") + 10.0)
	assert_signal_emit_count(_npcs, "trip_arrived", 1)
	assert_eq(npc.tile(), _tile_at(3, 3))
	assert_signal_emit_count(_npcs, "trip_blocked", 1, "told once")


func test_a_goal_that_is_not_loaded_blocks_the_trip_without_a_search() -> void:
	watch_signals(_npcs)
	var npc := _add_villager(_centre_of(_tile_at(0, 0)), _yard_middle())
	var far_away := _tile_at(0, 0) + Vector2i(Chunk.CHUNK_SIZE * 12, 0)
	_npcs.walk_to(npc, far_away, _world)
	_run(SECONDS)
	assert_signal_emitted_with_parameters(_npcs, "trip_blocked", [npc, NOT_LOADED])
	assert_eq(npc.trip.searches, 0)


func test_a_villager_whose_chunk_unloads_on_its_way_is_blocked() -> void:
	watch_signals(_npcs)
	var npc := _add_villager(_centre_of(_tile_at(-6, -5)), _yard_middle())
	_npcs.walk_to(npc, _tile_at(6, -5), _world)
	_run(2.0)
	_unload_chunk_of(npc.tile())
	_run(1.0)
	assert_signal_emitted_with_parameters(_npcs, "trip_blocked", [npc, NOT_LOADED])
	assert_signal_emit_count(_npcs, "trip_blocked", 1)
	assert_eq(npc.trip.searches, 1)


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


func test_a_skip_leaves_a_villager_on_a_trip_where_it_is() -> void:
	var npc := _add_villager(_centre_of(_tile_at(-6, -5)), _yard_middle())
	_npcs.walk_to(npc, _tile_at(6, -5), _world)
	_run(2.0)
	var at := npc.position
	_npcs.catch_up(_world, 1)
	assert_eq(npc.position, at)
	assert_true(npc.is_travelling())


func test_a_villager_is_not_placed_in_a_loaded_chunk_even_from_an_unloaded_one() -> void:
	var far := _add_villager(_centre_of(_tile_at(1, 1)), _yard_middle())
	_unload_chunk_of(far.tile())
	var at := far.position
	var chunks := _world.loaded_chunk_coords()
	var loaded_tile := Chunk.to_world(chunks[0], Vector2i(5, 5))
	assert_true(_world.is_chunk_loaded(Chunk.world_to_chunk(loaded_tile)))
	assert_false(_npcs.place(far, loaded_tile, _world))
	assert_eq(far.position, at)
