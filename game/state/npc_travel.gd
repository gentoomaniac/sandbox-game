class_name NpcTravel
extends RefCounted
## How villagers get to a place (task 238): a trip is started, a way is searched (PathSearch, worked
## by the Pathfinder within a frame's budget), the villager walks it tile by tile, goes round what
## has been put in its way, and, when there is no way, stands and looks again when the world has
## changed, until it is sent elsewhere. Npcs owns one and calls `update` for each villager that has
## a trip. The numbers are [travel] of data/npcs.cfg.

## The villager has reached the goal; its trip is over.
signal arrived(npc: Npc)
## No way was found (once for a trip, however often it looks again).
signal blocked(npc: Npc, reason: NpcTrip.Block)

var _rules: NpcRules
var _pathfinder: Pathfinder
var _villager_step := PathRules.default_rules().villager_step()


func _init(rules: NpcRules, clock := Callable(Time, "get_ticks_usec")) -> void:
	_rules = rules
	_pathfinder = Pathfinder.new(
		int(rules.travel("searches_per_frame")), int(rules.travel("search_usec_per_frame")), clock
	)


## Gives the searches their time for one frame.
func tick() -> void:
	_pathfinder.tick()


## Sends `npc` to the tile `goal` of `map`, instead of wherever it was going.
func start(npc: Npc, goal: Vector2i, map: GameMap) -> void:
	cancel(npc)
	if npc.tile() == goal:
		arrived.emit(npc)
		return
	npc.trip = NpcTrip.new(map, goal)
	_begin_search(npc)


## Ends the trip, with no signal: the one who did it knows.
func cancel(npc: Npc) -> void:
	if npc.trip != null and npc.trip.search != null:
		_pathfinder.drop(npc.trip.search)
	npc.trip = null


## Lets `delta` seconds pass for a villager with a trip. `fits` is a Callable `(npc, feet, map) ->
## bool` that says whether its body fits there.
func update(npc: Npc, delta: float, player_feet: Vector2, fits: Callable) -> void:
	var trip := npc.trip
	trip.seconds_since_search += delta
	match trip.state:
		NpcTrip.State.SEARCHING:
			_take_search_result(npc)
		NpcTrip.State.BLOCKED:
			if _has_cause_to_look_again(trip):
				trip.legs = 0
				trip.retries = 0
				_begin_search(npc)
		_:
			_walk(npc, delta, player_feet, fits)


func _begin_search(npc: Npc) -> void:
	var trip := npc.trip
	var map := trip.map
	var is_free := func(tile: Vector2i) -> bool:
		return Npcs.can_stand_at(map, Vector2(tile) + Vector2(0.5, 0.5))
	trip.search = PathSearch.new(
		npc.tile(),
		trip.goal,
		is_free,
		_cost_of(map),
		int(_rules.travel("max_nodes")),
		_rules.travel("heuristic_weight")
	)
	trip.searches += 1
	trip.state = NpcTrip.State.SEARCHING
	trip.seconds_since_search = 0.0
	trip.change_count_at_search = map.change_count
	_pathfinder.queue(trip.search)
	npc.activity = Npc.Activity.IDLE


## What stepping onto a tile costs: more for a crop, less for worn grass (the lanes), so they keep
## to what others have walked. Later ground (mud, roads) is weighed here.
func _cost_of(map: GameMap) -> Callable:
	var world := map as World
	var cost_trodden := _rules.travel("cost_trodden")
	var cost_path := _rules.travel("cost_path")
	var cost_object := _rules.travel("cost_object")
	return func(tile: Vector2i) -> float:
		var cost := 1.0
		if world != null:
			match world.wear_stage(tile):
				PathRules.Stage.TRODDEN:
					cost = cost_trodden
				PathRules.Stage.PATH:
					cost = cost_path
		if map.object_at(tile) != null:
			cost += cost_object
		return cost


func _take_search_result(npc: Npc) -> void:
	var trip := npc.trip
	var search := trip.search
	if search.state == PathSearch.State.RUNNING:
		return
	trip.search = null
	match search.state:
		PathSearch.State.FOUND:
			_walk_path(npc, search.path, false)
		PathSearch.State.LEG:
			trip.legs += 1
			if trip.legs > int(_rules.travel("max_legs")):
				_block(npc, NpcTrip.Block.NO_WAY)
			else:
				_walk_path(npc, search.path, true)
		_:
			_block(npc, NpcTrip.Block.NO_WAY)


## Whether a blocked villager has cause to search again: the world has changed since the last
## search (not sooner than `blocked_min_seconds` after it), or a long time has passed, for what
## changes without an edit, such as the tide.
func _has_cause_to_look_again(trip: NpcTrip) -> bool:
	if trip.seconds_since_search >= _rules.travel("blocked_fallback_seconds"):
		return true
	return (
		trip.map.change_count != trip.change_count_at_search
		and trip.seconds_since_search >= _rules.travel("blocked_min_seconds")
	)


func _block(npc: Npc, reason: NpcTrip.Block) -> void:
	var trip := npc.trip
	trip.state = NpcTrip.State.BLOCKED
	npc.activity = Npc.Activity.IDLE
	if not trip.is_blocked_told:
		trip.is_blocked_told = true
		blocked.emit(npc, reason)


## Starts walking `path`, which leads on from the tile `npc` stands on: first to the middle of
## that tile, so that its body is on the way the search found.
func _walk_path(npc: Npc, path: Array[Vector2i], is_leg: bool) -> void:
	var trip := npc.trip
	trip.path = path.duplicate()
	if not npc.position.is_equal_approx(Vector2(npc.tile()) + Vector2(0.5, 0.5)):
		trip.path.push_front(npc.tile())
	trip.next_index = 0
	trip.is_leg = is_leg
	trip.stuck_seconds = 0.0
	trip.state = NpcTrip.State.WALKING
	if trip.path.is_empty():
		_finish_path(npc)


func _finish_path(npc: Npc) -> void:
	if npc.trip.is_leg:
		_begin_search(npc)
		return
	npc.trip = null
	npc.activity = Npc.Activity.IDLE
	arrived.emit(npc)


## Steps along the path, if it may: it waits while the player talks to it or stands too close, and
## is stuck when its body does not fit on the next tile.
func _walk(npc: Npc, delta: float, player_feet: Vector2, fits: Callable) -> void:
	var trip := npc.trip
	if trip.pause_seconds > 0.0:
		trip.pause_seconds -= delta
		trip.state = NpcTrip.State.WAITING
		npc.activity = Npc.Activity.IDLE
		return
	var target := Vector2(trip.path[trip.next_index]) + Vector2(0.5, 0.5)
	var to_target := target - npc.position
	var reach := _rules.behaviour("walk_speed") * delta
	var feet := (
		target if to_target.length() <= reach else npc.position + to_target.normalized() * reach
	)
	var player_distance := npc.position.distance_to(player_feet)
	var new_player_distance := feet.distance_to(player_feet)
	if (
		new_player_distance < _rules.behaviour("personal_space")
		and new_player_distance < player_distance
	):
		trip.state = NpcTrip.State.WAITING
		npc.activity = Npc.Activity.IDLE
		return
	if not fits.call(npc, feet, trip.map):
		_be_stuck(npc, delta)
		return
	trip.state = NpcTrip.State.WALKING
	trip.stuck_seconds = 0.0
	var feet_tile := Vector2i(feet.floor())
	if feet_tile != npc.tile() and trip.map is World and _villager_step > 0.0:
		(trip.map as World).wear_tile(feet_tile, _villager_step)
	npc.position = feet
	if not to_target.is_zero_approx():
		npc.facing = Npc.facing_of(to_target)
		npc.heading = to_target.normalized()
	npc.activity = Npc.Activity.WALK
	if feet == target:
		trip.next_index += 1
		trip.retries = 0
		if trip.next_index == trip.path.size():
			_finish_path(npc)


## No free step: after `blocked_give_up_seconds` it looks for another way, `retries` times, and
## then the trip is blocked.
func _be_stuck(npc: Npc, delta: float) -> void:
	var trip := npc.trip
	npc.activity = Npc.Activity.IDLE
	trip.stuck_seconds += delta
	if trip.stuck_seconds <= _rules.travel("blocked_give_up_seconds"):
		return
	trip.stuck_seconds = 0.0
	trip.retries += 1
	if trip.retries > int(_rules.travel("retries")):
		_block(npc, NpcTrip.Block.STUCK)
		return
	trip.legs = 0
	_begin_search(npc)
