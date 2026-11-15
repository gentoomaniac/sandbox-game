class_name NpcTravel
extends RefCounted
## How villagers get to a place (task 238): a trip is started, a way is searched (PathSearch, run by
## the Pathfinder on a worker thread), the villager walks it tile by tile, goes round what has
## been put in its way, and, when there is no way, stands and looks again when the world has
## changed, until it is sent elsewhere. Npcs owns one and calls `update` for each villager that has
## a trip. The numbers are [travel] of data/npcs.cfg.
##
## How it all works: design/tech/pathfinding.md.

## The villager has reached the goal; its trip is over.
signal arrived(npc: Npc)
## No way was found (once for a trip, however often it looks again).
signal blocked(npc: Npc, reason: NpcTrip.Block)

## The numbers; Npcs hands on a change of them.
var rules: NpcRules:
	set(value):
		rules = value
		_pathfinder.max_tasks = int(value.travel("search_tasks"))
var _pathfinder: Pathfinder
## What a search sees of the world (see TravelView): the masks, made when the first search over a
## world asks for them, and the snapshot of the buildings and the wear, made again when old.
var _masks: TravelMasks
var _masks_world: World
var _snapshot: TravelSnapshot
var _clock: Callable


func _init(npc_rules: NpcRules, clock: Callable) -> void:
	_clock = clock
	_pathfinder = Pathfinder.new(1)
	rules = npc_rules


## Once a frame: lets the masks be made and takes in the searches that are done.
func tick() -> void:
	if _masks != null:
		_masks.update()
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
	if npc.trip != null:
		_drop_search(npc.trip)
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


## The path overlay's line (F4) on the trip of a villager: where from and to, how far it has got
## on its way (the leg it is on), and what the searching has cost.
static func text_of(npc: Npc) -> String:
	var trip := npc.trip
	var progress := ""
	match trip.state:
		NpcTrip.State.SEARCHING:
			progress = "searching"
		NpcTrip.State.WALKING:
			progress = "%d of %d tiles" % [trip.next_index, trip.path.size()]
		NpcTrip.State.WAITING:
			progress = "waiting"
		NpcTrip.State.BLOCKED:
			progress = "blocked (%s)" % NpcTrip.block_text(trip.block_reason)
	var nodes := trip.nodes_looked_at
	return (
		"path %s: %s -> %s, %s, leg %d, %d tiles looked at in %d searches"
		% [
			npc.name.get_slice(" ", 0),
			npc.tile(),
			trip.goal,
			progress,
			trip.legs,
			nodes,
			trip.searches
		]
	)


## `is_urgent`: the Pathfinder starts it before the others (a stuck villager the player can see).
func _begin_search(npc: Npc, is_urgent := false) -> void:
	var trip := npc.trip
	var map := trip.map
	var world := map as World
	assert(world != null, "A trip is over the tiles of a World")
	var masks := _masks_of(world)
	var view := TravelView.new(_snapshot_of(world), rules, world.clock.total_minutes())
	view.prefetch(masks, npc.tile(), trip.goal)
	trip.search = PathSearch.new(
		npc.tile(),
		trip.goal,
		view.is_free,
		view.cost_of,
		int(rules.travel("max_nodes")),
		rules.travel("heuristic_weight"),
		view.is_known
	)
	trip.searches += 1
	trip.state = NpcTrip.State.SEARCHING
	trip.seconds_since_search = 0.0
	trip.change_count_at_search = map.change_count
	# The queued search holds the view, which its Callables do not.
	_pathfinder.queue(trip.search, func() -> bool: return view.provide(masks), is_urgent)
	npc.activity = Npc.Activity.IDLE


## The masks of `world`, made again for another world.
func _masks_of(world: World) -> TravelMasks:
	if _masks_world != world:
		_masks = TravelMasks.for_world(world, rules)
		_masks_world = world
		# The snapshot is of the other world.
		_snapshot = null
	return _masks


## The snapshot of the world's buildings and wear, made again when it is not current.
func _snapshot_of(world: World) -> TravelSnapshot:
	var now: int = _clock.call()
	var most_usec := int(rules.travel("snapshot_seconds") * 1000000.0)
	if _snapshot == null or not _snapshot.is_current(world, now, most_usec):
		_snapshot = TravelSnapshot.of(world, now)
	return _snapshot


func _drop_search(trip: NpcTrip) -> void:
	if trip.search != null:
		_pathfinder.drop(trip.search)
		trip.search = null


## Whether walking over an object spoils it (a crop, a flower), as against a deck or a gate, which
## are made to be walked on. Static, so that the masks and the TravelView need no NpcTravel to ask.
static func is_trampled(object: WorldObject) -> bool:
	var type := object.type_data()
	return not type.get("deck", false) and not type.has("connects")


func _take_search_result(npc: Npc) -> void:
	var trip := npc.trip
	var search := trip.search
	if not _pathfinder.is_finished(search):
		return
	_pathfinder.take(search)
	trip.search = null
	trip.nodes_looked_at += search.nodes_looked_at
	match search.state:
		PathSearch.State.FOUND:
			_walk_path(npc, search.path, false)
		PathSearch.State.LEG:
			trip.legs += 1
			if trip.legs > int(rules.travel("max_legs")):
				_block(npc, NpcTrip.Block.NO_WAY)
			else:
				_walk_path(npc, search.path, true)
		_:
			_block(npc, NpcTrip.Block.NO_WAY)


## Whether a blocked villager has cause to search again: the world has changed since the last
## search (not sooner than `blocked_min_seconds` after it), or a long time has passed, for what
## changes without an edit, such as the tide.
func _has_cause_to_look_again(trip: NpcTrip) -> bool:
	if trip.seconds_since_search >= rules.travel("blocked_fallback_seconds"):
		return true
	return (
		trip.map.change_count != trip.change_count_at_search
		and trip.seconds_since_search >= rules.travel("blocked_min_seconds")
	)


func _block(npc: Npc, reason: NpcTrip.Block) -> void:
	var trip := npc.trip
	trip.state = NpcTrip.State.BLOCKED
	trip.block_reason = reason
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
## is stuck when the step is not free. Where the world answers for by itself (`_is_step_whole`) the
## step is checked live, with the body (`fits`); elsewhere, far from the player, only the tile it
## enters is checked, against the mask of its chunk at the time of entry (the tide, the season), and
## a tile whose mask is not there yet (an edit dropped it) is waited for. Both ways move towards the
## same tile centre at the same speed, so the position does not jump when a chunk loads or unloads
## between two centres.
func _walk(npc: Npc, delta: float, player_feet: Vector2, fits: Callable) -> void:
	var trip := npc.trip
	if trip.pause_seconds > 0.0:
		trip.pause_seconds -= delta
		trip.state = NpcTrip.State.WAITING
		npc.activity = Npc.Activity.IDLE
		return
	var next_tile := trip.path[trip.next_index]
	var target := Vector2(next_tile) + Vector2(0.5, 0.5)
	var to_target := target - npc.position
	var reach := rules.behaviour("walk_speed") * delta
	var feet := (
		target if to_target.length() <= reach else npc.position + to_target.normalized() * reach
	)
	if Npcs.is_crowding_player(npc.position, feet, player_feet, rules.behaviour("personal_space")):
		trip.state = NpcTrip.State.WAITING
		npc.activity = Npc.Activity.IDLE
		return
	var world := trip.map as World
	if _is_step_whole(world, feet, next_tile):
		if not fits.call(npc, feet, trip.map):
			_be_stuck(npc, delta)
			return
		Npcs.wear_step(trip.map, feet, npc.tile())
	elif not _may_enter_far_tile(npc, world, feet, delta):
		return
	trip.state = NpcTrip.State.WALKING
	trip.stuck_seconds = 0.0
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


## Whether the world answers for a step to `feet`, towards `next_tile`, by itself: for the tile and
## for every tile the body touches there. The body reaches a little over the edge of its tile, so
## it can touch ground that is not loaded while the tile is.
static func _is_step_whole(world: World, feet: Vector2, next_tile: Vector2i) -> bool:
	if not _is_whole(world, next_tile):
		return false
	var body := PlayerState.body_tiles(feet)
	for y in range(body.position.y, body.end.y):
		for x in range(body.position.x, body.end.x):
			if not _is_whole(world, Vector2i(x, y)):
				return false
	return true


## Whether the world answers for the tile by itself: its chunk and the ones a big object can reach
## it from are loaded. On the rim of the loaded area a tile whose west or north neighbour is not
## loaded is left to the mask, which has those objects, as the live answer has not.
static func _is_whole(world: World, tile: Vector2i) -> bool:
	var coords := Chunk.world_to_chunk(tile)
	for step in TravelMasks.SOURCE_STEPS:
		if not world.is_chunk_loaded(coords + step):
			return false
	return true


## The far step of `_walk`: whether the walker may move to `feet`. Only entering a new tile asks
## anything, and wears it (a loaded tile as the near step does, one that is not loaded where the
## mask says grass wears). A tile that is closed makes it stuck; one whose mask is being made
## makes it stand and wait, which is not being stuck.
func _may_enter_far_tile(npc: Npc, world: World, feet: Vector2, delta: float) -> bool:
	# The body is checked afresh when it is on loaded ground again.
	npc.free_body_tiles = Rect2i()
	var tile := Vector2i(feet.floor())
	if tile == npc.tile():
		return true
	var coords := Chunk.world_to_chunk(tile)
	var mask := _masks_of(world).mask_of(coords)
	if mask == null:
		npc.activity = Npc.Activity.IDLE
		return false
	var minutes := world.clock.total_minutes()
	var local := Chunk.local_pos(tile)
	if (
		world.building_at(tile) != null
		or not mask.is_free(local, Tide.level(minutes), GameClock.day_of(minutes))
	):
		_be_stuck(npc, delta)
		return false
	if world.is_chunk_loaded(coords):
		Npcs.wear_step(world, feet, npc.tile())
	elif mask.wears(local):
		world.wear_unloaded(tile, PathRules.default_rules().villager_step())
	return true


## No free step: after `blocked_give_up_seconds` it looks for another way, `retries` times, and
## then the trip is blocked.
func _be_stuck(npc: Npc, delta: float) -> void:
	var trip := npc.trip
	npc.activity = Npc.Activity.IDLE
	trip.stuck_seconds += delta
	if trip.stuck_seconds <= rules.travel("blocked_give_up_seconds"):
		return
	trip.stuck_seconds = 0.0
	trip.retries += 1
	if trip.retries > int(rules.travel("retries")):
		_block(npc, NpcTrip.Block.STUCK)
		return
	trip.legs = 0
	_begin_search(npc, (trip.map as World).is_chunk_loaded(Chunk.world_to_chunk(npc.tile())))
