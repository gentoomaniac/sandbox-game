extends NpcCase
## NpcTravel: what a way costs, a trip given up after the retries, a way that takes several legs,
## and the one tick of the searches in each update of the villagers.

const SECONDS := 60.0


func _tile_at(x: int, y: int) -> Vector2i:
	return _middle + Vector2i(x, y)


func _centre_of(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


## The rules of the data file with `[travel]` values changed.
func _rules_with(changes: Dictionary) -> NpcRules:
	var values := DataFile.read_sections(NpcRules.DEFAULT_PATH)
	values["travel"].merge(changes, true)
	return NpcRules.new(values)


func _run_until(is_done: Callable, seconds := SECONDS) -> bool:
	for _i in roundi(seconds / STEP_SECONDS):
		if is_done.call():
			return true
		_step()
	return is_done.call()


## A wall of fence along x = 0 of the yard with a gap at its south end, and `in_it` at (0, 0).
## Returns the tiles a villager sent from (-3, 0) to (3, 0) stood on.
func _tiles_stood_on_through_a_wall_with(in_it: StringName) -> Array[Vector2i]:
	_npcs.rules = _rules_with({"cost_object": 100.0})
	for y in range(-9, 9):
		_world.remove_object(_tile_at(0, y))
		_world.add_object(
			WorldObject.new(in_it if y == 0 else WorldObjectTypes.PEN_FENCE, _tile_at(0, y))
		)
	var npc := _add_villager(_centre_of(_tile_at(-3, 0)), _yard_middle())
	_npcs.walk_to(npc, _tile_at(3, 0), _world)
	var tiles: Array[Vector2i] = []
	var is_there := func() -> bool:
		tiles.append(npc.tile())
		return not npc.is_travelling()
	assert_true(_run_until(is_there))
	return tiles


func test_a_gate_is_walked_through_however_much_a_crop_costs() -> void:
	assert_has(_tiles_stood_on_through_a_wall_with(WorldObjectTypes.PEN_GATE), _tile_at(0, 0))


func test_a_deck_is_walked_over_however_much_a_crop_costs() -> void:
	assert_has(_tiles_stood_on_through_a_wall_with(WorldObjectTypes.JETTY), _tile_at(0, 0))


func test_tall_grass_is_walked_round_when_a_crop_costs_much() -> void:
	assert_does_not_have(
		_tiles_stood_on_through_a_wall_with(WorldObjectTypes.TALL_GRASS), _tile_at(0, 0)
	)


func test_a_trip_is_blocked_as_stuck_when_the_retries_are_used_up() -> void:
	var travel := NpcTravel.new(_npcs.rules, Callable(Time, "get_ticks_usec"))
	watch_signals(travel)
	var npc := _add_villager(_centre_of(_tile_at(-3, 0)), _yard_middle())
	travel.start(npc, _tile_at(3, 0), _world)
	var never_fits := func(_npc: Npc, _feet: Vector2, _map: GameMap) -> bool: return false
	var far_off := _centre_of(_tile_at(0, 40))
	# Frames until it is told, with a generous bound: searches take the time they take.
	for _i in 20000:
		if get_signal_emit_count(travel, "blocked") > 0:
			break
		travel.tick()
		travel.update(npc, STEP_SECONDS, far_off, never_fits)
		OS.delay_usec(1000)
	assert_signal_emit_count(travel, "blocked", 1)
	assert_signal_emitted_with_parameters(travel, "blocked", [npc, NpcTrip.Block.STUCK])
	assert_eq(npc.trip.searches, 1 + int(_npcs.rules.travel("retries")))


func test_a_way_of_several_legs_is_walked_and_one_of_too_many_legs_is_blocked() -> void:
	_npcs.rules = _rules_with({"max_nodes": 12, "max_legs": 50})
	watch_signals(_npcs)
	var npc := _add_villager(_centre_of(_tile_at(-8, -8)), _yard_middle())
	_npcs.walk_to(npc, _tile_at(8, 8), _world)
	var most_legs := [0]
	var is_there := func() -> bool:
		most_legs[0] = maxi(most_legs[0], npc.trip.legs if npc.is_travelling() else 0)
		return not npc.is_travelling()
	assert_true(_run_until(is_there))
	assert_gt(most_legs[0], 1, "no one search sees so far")
	assert_eq(npc.tile(), _tile_at(8, 8))
	_npcs.rules = _rules_with({"max_nodes": 12, "max_legs": 1})
	_npcs.walk_to(npc, _tile_at(-8, -8), _world)
	_run_until(func() -> bool: return not npc.is_travelling(), 30.0)
	assert_signal_emitted_with_parameters(_npcs, "trip_blocked", [npc, NpcTrip.Block.NO_WAY])


func test_only_as_many_searches_run_at_once_as_the_rules_say_and_all_are_done_in_the_end() -> void:
	_npcs.rules = _rules_with({"search_tasks": 1})
	var searching: Array[Npc] = []
	for index in 4:
		var npc := Npc.create(SEED + index, _centre_of(_tile_at(-8, -8)), _npcs.rules)
		_npcs.add(npc)
		_npcs.walk_to(npc, _tile_at(8, 8), _world)
		searching.append(npc)
	var all_have_their_way := func() -> bool:
		return searching.all(
			func(npc: Npc) -> bool: return npc.trip.state != NpcTrip.State.SEARCHING
		)
	assert_true(_run_until(all_have_their_way))


func test_the_f3_line_names_the_trip_of_the_nearest_villager_on_one() -> void:
	assert_eq(_npcs.path_text(_yard_middle()), "", "nobody is on a trip")
	var near := _add_villager(_centre_of(_tile_at(-3, 0)), _yard_middle())
	var far := _add_villager(_centre_of(_tile_at(8, 8)), _yard_middle())
	_npcs.walk_to(near, _tile_at(3, 0), _world)
	_npcs.walk_to(far, _tile_at(-8, -8), _world)
	var text := _npcs.path_text(_centre_of(_tile_at(-3, 1)))
	assert_string_contains(text, "-> %s" % _tile_at(3, 0))
	assert_string_contains(text, "searching")
	_step()
	_step()
	assert_string_contains(_npcs.path_text(_centre_of(_tile_at(-3, 1))), "tiles,")


func test_a_trip_cancelled_while_it_searches_never_arrives() -> void:
	watch_signals(_npcs)
	var npc := _add_villager(_centre_of(_tile_at(-3, 0)), _yard_middle())
	_npcs.walk_to(npc, _tile_at(3, 0), _world)
	_npcs.cancel_trip(npc)
	for _i in 100:
		_step()
		OS.delay_usec(1000)
	assert_false(npc.is_travelling())
	assert_signal_emit_count(_npcs, "trip_arrived", 0)


func test_a_trip_over_another_world_does_not_use_the_snapshot_of_the_first() -> void:
	var travel := NpcTravel.new(_npcs.rules, Callable(Time, "get_ticks_usec"))
	var npc := _add_villager(_centre_of(_tile_at(-3, 0)), _yard_middle())
	travel.start(npc, _tile_at(3, 0), _world)
	var first := travel._snapshot
	assert_not_null(first)
	var other := World.new(SEED)
	other.clock = GameClock.new()
	other.change_count = _world.change_count
	var other_npc := _add_villager(_centre_of(_tile_at(-3, 0)), _yard_middle())
	travel.start(other_npc, _tile_at(3, 0), other)
	assert_ne(travel._snapshot, first, "the same change count, but another world")
	travel.cancel(npc)
	travel.cancel(other_npc)


## A villager at the tile (-8, -5) of the yard on a trip along `tiles` (given as offsets from the
## middle of the yard), its way found already.
func _walker_along(tiles: Array[Vector2i]) -> Npc:
	var npc := _add_villager(_centre_of(_tile_at(-8, -5)), _yard_middle())
	var trip := NpcTrip.new(_world, _middle + tiles.back())
	for tile in tiles:
		trip.path.append(_middle + tile)
	trip.state = NpcTrip.State.WALKING
	npc.trip = trip
	return npc


func _row_of_tiles(from_x: int, to_x: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(from_x, to_x + 1):
		tiles.append(Vector2i(x, -5))
	return tiles


func _walk_frames(frames: int, delta: float) -> void:
	for _i in frames:
		_npcs.update(delta, _world, _state.player.position, _state.clock)


func test_a_walker_covers_walk_speed_times_the_time_over_frames_of_any_length() -> void:
	var speed: float = _npcs.rules.behaviour("walk_speed")
	for delta in [0.05, 0.037, 0.011]:
		var npc := _walker_along(_row_of_tiles(-7, 8))
		var frames := roundi(5.0 / delta)
		var from_x := npc.position.x
		_walk_frames(frames, delta)
		assert_almost_eq(npc.position.x - from_x, speed * delta * frames, 0.001, "delta %s" % delta)
		_npcs.cancel_trip(npc)
		_npcs.remove(npc)


func test_a_walker_never_covers_more_than_walk_speed_times_the_frame() -> void:
	var reach: float = _npcs.rules.behaviour("walk_speed") * STEP_SECONDS
	var npc := _walker_along(_row_of_tiles(-7, 8))
	for _i in 100:
		var before := npc.position
		_walk_frames(1, STEP_SECONDS)
		assert_lte(before.distance_to(npc.position), reach + 0.0001)


func test_a_walker_takes_a_corner_in_the_path_without_losing_distance() -> void:
	var speed: float = _npcs.rules.behaviour("walk_speed")
	var tiles: Array[Vector2i] = [
		Vector2i(-7, -5), Vector2i(-6, -5), Vector2i(-6, -4), Vector2i(-6, -3)
	]
	var npc := _walker_along(tiles)
	var seconds := 2.4 / speed
	_walk_frames(roundi(seconds / STEP_SECONDS), STEP_SECONDS)
	assert_almost_eq(npc.position.x, _tile_at(-6, 0).x + 0.5, 0.0001, "round the corner")
	assert_almost_eq(npc.position.y, _tile_at(0, -5).y + 0.5 + 0.4, 0.0001, "0.4 tiles past it")
	assert_eq(npc.trip.next_index, 2)


func test_a_walker_stops_at_a_tile_centre_when_the_next_tile_is_blocked() -> void:
	var blocked_tile := _tile_at(-5, -5)
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, blocked_tile))
	var npc := _walker_along(_row_of_tiles(-7, -5))
	_walk_frames(200, STEP_SECONDS)
	assert_lt(npc.position.x, float(blocked_tile.x), "it did not enter the tile")
	assert_eq(npc.trip.next_index, 2, "it reached the centre before it")
	assert_true(npc.is_travelling())
