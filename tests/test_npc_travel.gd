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
	for _i in roundi(SECONDS / STEP_SECONDS):
		travel.tick()
		travel.update(npc, STEP_SECONDS, far_off, never_fits)
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


func test_the_searches_are_ticked_once_in_each_update_however_many_villagers() -> void:
	var now := [0]
	var clock := func() -> int:
		var at: int = now[0]
		now[0] += 100
		return at
	var npcs := Npcs.new(_state.sun, clock)
	npcs.rules = _rules_with({"search_usec_per_frame": 200})
	var searching: Array[Npc] = []
	for index in 3:
		var npc := Npc.create(SEED + index, _centre_of(_tile_at(-8, -8)), npcs.rules)
		npcs.add(npc)
		npcs.walk_to(npc, _tile_at(8, 8), _world)
		searching.append(npc)
	_state.clock.day = DAY
	_state.clock.minute_of_day = NOON
	var looked_at := func() -> int:
		var total := 0
		for npc in searching:
			total += npc.trip.search.nodes_looked_at if npc.trip.search != null else 0
		return total
	npcs.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
	var per_tick: int = looked_at.call()
	assert_eq(per_tick, Pathfinder.NODES_PER_CHECK, "200 us is one step, then the time is out")
	npcs.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
	assert_eq(looked_at.call(), 2 * per_tick)


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
