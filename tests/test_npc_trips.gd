extends NpcCase
## A villager sent to a tile (Npcs `walk_to`): it finds its way, goes round what is put in it, waits
## for the player and for a talk, stands and looks again when there is no way, and goes on at night.

const SECONDS := 20
const FENCE := WorldObjectTypes.PEN_FENCE
const GATE := WorldObjectTypes.PEN_GATE


func _tile_at(x: int, y: int) -> Vector2i:
	return _middle + Vector2i(x, y)


func _centre_of(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


## A villager at the middle of the tile (x, y) of the yard, sent to the tile (goal_x, goal_y).
func _send(x: int, y: int, goal_x: int, goal_y: int) -> Npc:
	var npc := _add_villager(_centre_of(_tile_at(x, y)), _yard_middle())
	_npcs.walk_to(npc, _tile_at(goal_x, goal_y), _world)
	return npc


func _run(seconds: float, minute := NOON) -> void:
	for _i in roundi(seconds / STEP_SECONDS):
		_step(minute)


## Steps until `is_done` says so, for up to `seconds`; returns whether it did.
func _run_until(is_done: Callable, seconds := 60.0, minute := NOON) -> bool:
	for _i in roundi(seconds / STEP_SECONDS):
		if is_done.call():
			return true
		_step(minute)
	return is_done.call()


## Puts a fence on every tile around `tile`, the eight that touch it.
func _fence_in(tile: Vector2i) -> Array[Vector2i]:
	var fences: Array[Vector2i] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			if x != 0 or y != 0:
				fences.append(tile + Vector2i(x, y))
				_world.add_object(WorldObject.new(FENCE, tile + Vector2i(x, y)))
	return fences


func test_a_villager_walks_to_the_tile_it_is_sent_to() -> void:
	watch_signals(_npcs)
	var npc := _send(-6, -5, 6, -6)
	assert_true(npc.is_travelling())
	assert_true(_run_until(func() -> bool: return not npc.is_travelling()))
	assert_eq(npc.tile(), _tile_at(6, -6))
	assert_signal_emit_count(_npcs, "trip_arrived", 1)
	assert_signal_not_emitted(_npcs, "trip_blocked")


func test_a_villager_who_is_there_already_arrives_at_once() -> void:
	watch_signals(_npcs)
	var npc := _send(3, 3, 3, 3)
	assert_signal_emit_count(_npcs, "trip_arrived", 1)
	assert_false(npc.is_travelling())


func test_a_villager_goes_through_a_gate_and_round_a_fence() -> void:
	# A fence across the yard with a gate in it, and the way round it is far.
	for y in range(-9, 10):
		_world.remove_object(_tile_at(0, y))
		_world.add_object(WorldObject.new(GATE if y == 7 else FENCE, _tile_at(0, y)))
	var npc := _send(-5, -6, 5, -6)
	var passed_the_fence_at: Array[int] = []
	var is_there := func() -> bool:
		if npc.tile().x == _middle.x:
			passed_the_fence_at.append(npc.tile().y)
		return not npc.is_travelling()
	assert_true(_run_until(is_there))
	assert_eq(npc.tile(), _tile_at(5, -6))
	assert_eq(passed_the_fence_at.min(), _middle.y + 7, "through the gate")
	assert_eq(passed_the_fence_at.max(), _middle.y + 7)


func test_a_fence_put_on_its_way_is_gone_round() -> void:
	var npc := _send(-6, -5, 6, -5)
	_run(2.0)
	var trip := npc.trip
	var fence := trip.path[trip.next_index + 3]
	_world.add_object(WorldObject.new(FENCE, fence))
	var tiles_stood_on: Array[Vector2i] = []
	var is_there := func() -> bool:
		tiles_stood_on.append(npc.tile())
		return not npc.is_travelling()
	assert_true(_run_until(is_there))
	assert_does_not_have(tiles_stood_on, fence)
	assert_eq(npc.tile(), _tile_at(6, -5))


func test_a_closed_in_goal_blocks_once_and_is_got_to_when_a_fence_goes() -> void:
	watch_signals(_npcs)
	var goal := _tile_at(5, -5)
	var fences := _fence_in(goal)
	var npc := _send(-5, -5, 5, -5)
	_run(SECONDS)
	assert_signal_emit_count(_npcs, "trip_blocked", 1)
	assert_signal_emitted_with_parameters(_npcs, "trip_blocked", [npc, NpcTrip.Block.NO_WAY])
	assert_true(npc.is_travelling())
	_run(SECONDS)
	assert_signal_emit_count(_npcs, "trip_blocked", 1, "once")
	_world.remove_object(fences[1])
	assert_true(_run_until(func() -> bool: return not npc.is_travelling(), 30.0))
	assert_eq(npc.tile(), goal)
	assert_signal_emit_count(_npcs, "trip_arrived", 1)


func test_a_blocked_villager_in_a_static_world_looks_again_after_the_fallback() -> void:
	_fence_in(_tile_at(5, -5))
	var npc := _send(-5, -5, 5, -5)
	var fallback := _npcs.rules.travel("blocked_fallback_seconds")
	_run(fallback - 10.0)
	assert_eq(npc.trip.searches, 1)
	_run(20.0)
	assert_eq(npc.trip.searches, 2)


func test_a_blocked_villager_looks_again_when_the_world_has_changed() -> void:
	_fence_in(_tile_at(5, -5))
	var npc := _send(-5, -5, 5, -5)
	_run(SECONDS)
	assert_eq(npc.trip.searches, 1)
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _tile_at(8, 8)))
	_run(_npcs.rules.travel("blocked_min_seconds") + 1.0)
	assert_eq(npc.trip.searches, 2)


func test_waiting_for_the_player_is_not_being_stuck() -> void:
	watch_signals(_npcs)
	var npc := _send(-6, -5, 6, -5)
	_state.player.position = _centre_of(_tile_at(0, -5))
	_run(SECONDS)
	assert_eq(npc.trip.state, NpcTrip.State.WAITING)
	assert_eq(npc.trip.stuck_seconds, 0.0)
	assert_eq(npc.trip.searches, 1)
	assert_signal_not_emitted(_npcs, "trip_blocked")
	_state.player.position = _centre_of(_tile_at(0, 40))
	assert_true(_run_until(func() -> bool: return not npc.is_travelling()))
	assert_eq(npc.tile(), _tile_at(6, -5))


func test_a_talk_pauses_the_trip_and_does_not_end_it() -> void:
	watch_signals(_npcs)
	var npc := _send(-6, -5, 6, -5)
	_run(2.0)
	_npcs.talk_to(npc, _state.player.position)
	var stood_at := npc.position
	_run(_npcs.rules.behaviour("linger_seconds") - 1.0)
	assert_eq(npc.position, stood_at)
	assert_true(npc.is_travelling())
	assert_true(_run_until(func() -> bool: return not npc.is_travelling()))
	assert_signal_not_emitted(_npcs, "trip_blocked")
	assert_eq(npc.tile(), _tile_at(6, -5))


func test_a_trip_goes_on_at_night() -> void:
	var npc := _send(-6, -5, 6, -5)
	assert_true(_run_until(func() -> bool: return not npc.is_travelling(), 60.0, MIDNIGHT))
	assert_eq(npc.tile(), _tile_at(6, -5))


func test_a_trip_that_is_cancelled_ends_with_no_signal_and_the_villager_stands() -> void:
	watch_signals(_npcs)
	var npc := _send(-6, -5, 6, -5)
	_run(1.0)
	_npcs.cancel_trip(npc)
	assert_false(npc.is_travelling())
	assert_signal_not_emitted(_npcs, "trip_arrived")
	assert_signal_not_emitted(_npcs, "trip_blocked")


func test_a_new_trip_replaces_the_old_one() -> void:
	var npc := _send(-6, -5, 6, -5)
	_run(1.0)
	_npcs.walk_to(npc, _tile_at(-6, 5), _world)
	assert_true(_run_until(func() -> bool: return not npc.is_travelling()))
	assert_eq(npc.tile(), _tile_at(-6, 5))
