extends NpcRoadCase
## A time skip takes a villager on a trip along its path as far as the same minutes of play (#68):
## a tile a minute, over the masks, to its goal or to where the way is closed, with no search.

const HOME_X := 10


func before_each() -> void:
	super()
	_build_road()
	_warm_road_masks()


func after_each() -> void:
	Simulation.frame_budget_usec = Simulation.DEFAULT_FRAME_BUDGET_USEC


## Plays `minutes` of game time in frames of 1/24 s, which take a villager 1/16 of a tile each:
## a walker ends a tile in a whole number of them (a step that ends one wastes what is left of it).
func _play_minutes(minutes: int) -> void:
	var seconds := minutes / GameClock.GAME_MINUTES_PER_REAL_SECOND
	for _i in roundi(seconds * 24.0):
		_npcs.update(1.0 / 24.0, _world, _state.player.position, _state.clock)


func _next_frame() -> Signal:
	return get_tree().process_frame


func test_a_skip_moves_a_trip_as_far_as_the_same_minutes_of_play() -> void:
	var npc := _walker_on_road(ROAD_LENGTH, HOME_X)
	_play_minutes(37)
	var played := npc.position
	_send_along_road(npc, ROAD_LENGTH, HOME_X)
	_skip_minutes(37)
	assert_eq(npc.tile(), Vector2i(played.floor()))
	assert_almost_eq(npc.position.x, played.x, 0.1)
	assert_eq(npc.tile(), _road_tile(ROAD_LENGTH - 37))
	assert_true(npc.is_travelling(), "the trip goes on")


func test_a_trip_from_the_middle_of_a_tile_goes_on_from_there() -> void:
	var npc := _walker_on_road(ROAD_LENGTH, HOME_X)
	for _i in 10:
		_step()
	var from := npc.position
	assert_ne(from.x, floorf(from.x) + 0.5, "between two centres")
	_skip_minutes(20)
	assert_almost_eq(npc.position.x, from.x - 20.0, 0.01)
	assert_eq(npc.trip.next_index, 20)


func test_the_walked_minutes_of_a_skip_and_the_rest_move_a_trip_once() -> void:
	var npc := _walker_on_road(ROAD_LENGTH, HOME_X)
	_state.simulation.skip(30)
	assert_eq(npc.tile(), _road_tile(ROAD_LENGTH - 30))


func test_a_trip_that_ends_in_the_skip_arrives_once() -> void:
	watch_signals(_npcs)
	var npc := _walker_on_road(ROAD_LENGTH, HOME_X)
	_skip_minutes(300)
	assert_signal_emit_count(_npcs, "trip_arrived", 1)
	assert_eq(npc.tile(), _road_tile(HOME_X))
	assert_false(npc.is_travelling())
	_skip_minutes(300)
	assert_signal_emit_count(_npcs, "trip_arrived", 1, "not again")


func test_a_trip_without_a_path_searches_after_the_skip() -> void:
	watch_signals(_npcs)
	var npc := _add_villager(_centre_of(_road_tile(ROAD_LENGTH)), _yard_middle())
	_npcs.walk_to(npc, _middle, _world)
	var at := npc.position
	_skip_minutes(60)
	assert_eq(npc.position, at, "it stands")
	assert_eq(npc.trip.state, NpcTrip.State.SEARCHING)
	assert_true(_run_until(func() -> bool: return not npc.is_travelling()))
	assert_eq(npc.trip.searches if npc.trip != null else 1, 1, "one search, after the skip")
	assert_eq(npc.tile(), _middle)
	assert_signal_emit_count(_npcs, "trip_arrived", 1)


func test_a_blocked_trip_looks_again_soon_after_a_skip() -> void:
	var npc := _walker_on_road(ROAD_LENGTH, HOME_X)
	npc.trip.state = NpcTrip.State.BLOCKED
	_skip_minutes(200)
	assert_gte(
		npc.trip.seconds_since_search, _npcs.rules.travel("blocked_fallback_seconds"), "it looks"
	)


func test_a_talk_does_not_hold_a_walker_up_in_a_skip() -> void:
	var npc := _walker_on_road(ROAD_LENGTH, HOME_X)
	_npcs.talk_to(npc, _state.player.position)
	_skip_minutes(10)
	assert_eq(npc.tile(), _road_tile(ROAD_LENGTH - 10))


func test_synchronous_and_over_frames_end_the_same_with_masks_not_made_yet() -> void:
	var cold := _npcs._travel._masks_of(_world)
	for coords in cold.mask_coords():
		_world.edited.emit(coords)
	assert_eq(cold.mask_coords().size(), 0, "no mask is made")
	var npc := _walker_on_road(ROAD_LENGTH, HOME_X)
	_state.clock.minute_of_day += 80
	await _npcs.catch_up_over_frames(_world, 1, 80, _next_frame)
	var over_frames := npc.position
	_send_along_road(npc, ROAD_LENGTH, HOME_X)
	_state.clock.minute_of_day -= 80
	_skip_minutes(80)
	assert_eq(npc.position, over_frames)
	assert_eq(npc.tile(), _road_tile(ROAD_LENGTH - 80))


func test_a_path_over_more_chunks_than_the_masks_kept_is_walked_to_its_end() -> void:
	var values := DataFile.read_sections(NpcRules.DEFAULT_PATH)
	values["travel"]["far_masks_kept"] = 2
	values["travel"]["far_chunks_kept"] = 4
	values["travel"]["skip_masks_ahead"] = 3
	_npcs.rules = NpcRules.new(values)
	var masks: TravelMasks = _npcs._travel._masks_of(_world)
	assert_eq(masks.mask_coords().size(), 0, "none made yet")
	var npc := _walker_on_road(ROAD_LENGTH, HOME_X)
	_state.clock.minute_of_day += 90
	await _npcs.catch_up_over_frames(_world, 1, 90, _next_frame)
	assert_eq(npc.tile(), _road_tile(ROAD_LENGTH - 90))
	masks.wait_for_mask(Chunk.world_to_chunk(_road_tile(HOME_X)) + Vector2i(0, 5))
	assert_lte(masks.mask_coords().size(), 2, "and let go of after it")


func test_a_skip_wears_the_grass_the_walker_crosses() -> void:
	_walker_on_road(ROAD_LENGTH, HOME_X)
	_skip_minutes(20)
	var worn := _world.wear_steps()
	for x in range(ROAD_LENGTH - 19, ROAD_LENGTH):
		assert_true(worn.has(_road_tile(x)), "the grass of %s is worn" % _road_tile(x))


func test_a_villager_in_the_loaded_yard_may_be_placed_in_a_skip_but_not_otherwise() -> void:
	var seen := _add_villager(_yard_middle(), _yard_middle())
	assert_false(_npcs.place(seen, _road_tile(ROAD_LENGTH), _world), "not when seen")
	var placed := [false]
	_npcs.trip_arrived.connect(
		func(_npc: Npc) -> void: placed[0] = _npcs.place(seen, _road_tile(ROAD_LENGTH), _world)
	)
	_walker_on_road(HOME_X + 3, HOME_X)
	_skip_minutes(10)
	assert_true(placed[0], "in a skip it may")
	assert_eq(seen.tile(), _road_tile(ROAD_LENGTH))
	assert_false(_npcs.is_skipping)
