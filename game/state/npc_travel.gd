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

## A frame crosses at most this many tile centres; the rest of a longer one is dropped.
const MAX_TILES_PER_UPDATE := 8

## The numbers; Npcs hands on a change of them.
var rules: NpcRules:
	set(value):
		rules = value
		_pathfinder.max_tasks = int(value.travel("search_tasks"))
		# Made again, so that new limits (`far_masks_kept`, `skip_masks_ahead`) apply to them.
		_masks_world = null
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


## Begins `npc`'s trip through a skip of `minutes` that the clock shows the end of (see
## `advance_skip`); null when the villager has no way to walk: one that has none yet, or is blocked,
## stands where it is and searches after the skip, as in play. The player does not hold a walker up
## in a skip.
func begin_skip(npc: Npc, minutes: int) -> NpcSkip:
	var trip := npc.trip
	trip.seconds_since_search += minutes / GameClock.GAME_MINUTES_PER_REAL_SECOND
	if trip.state != NpcTrip.State.WALKING and trip.state != NpcTrip.State.WAITING:
		return null
	trip.pause_seconds = 0.0
	trip.state = NpcTrip.State.WALKING
	var tiles := minutes * rules.behaviour("walk_speed") / GameClock.GAME_MINUTES_PER_REAL_SECOND
	return NpcSkip.new(npc, tiles, (trip.map as World).clock.total_minutes() - minutes)


## Walks the trip of `skip` as far as the minutes of the skip take it: a tile a minute along its
## path, as in play (`_walk`), at the speed of play, over the masks everywhere, loaded ground
## too. Each tile is asked at the minute the walker enters it: the tide and the season of that time,
## not the clock's, which is at the end of the skip. The world is that of the end of the skip,
## so a tile that is closed then stops it there, to search after the skip; none is searched
## inside it. The villager arrives (`arrived`, once) when its path ends in the skip.
##
## Returns false, with the chunk in `skip.missing_mask`, when the mask of a tile is not made
## yet: let the worker go on (`make_masks`) and call again; nothing has been done twice.
## True when it is over.
func advance_skip(skip: NpcSkip) -> bool:
	var npc := skip.npc
	var trip := npc.trip
	# Its trip was taken from it between two calls (over frames): the skip is over.
	if trip == null:
		if _masks != null:
			for coords in skip.pinned:
				_masks.unpin(coords)
		skip.pinned.clear()
		return true
	var world := trip.map as World
	var masks := _masks_of(world)
	var tiles_per_minute := rules.behaviour("walk_speed") / GameClock.GAME_MINUTES_PER_REAL_SECOND
	while npc.trip == trip and trip.state == NpcTrip.State.WALKING and skip.tiles_left > 0.0:
		var next_tile := trip.path[trip.next_index]
		var target := Vector2(next_tile) + Vector2(0.5, 0.5)
		var distance := npc.position.distance_to(target)
		var steps := minf(distance, skip.tiles_left)
		_ask_masks_ahead(skip, masks)
		# The feet cross into the tile half a tile before its middle.
		var until_border := maxf(distance - 0.5, 0.0)
		if next_tile != npc.tile() and until_border <= skip.tiles_left:
			var coords := Chunk.world_to_chunk(next_tile)
			var mask := masks.mask_of(coords)
			if mask == null:
				skip.missing_mask = coords
				return false
			var minute := (
				skip.start_minute + int((skip.tiles_walked + until_border) / tiles_per_minute)
			)
			if not _is_tile_open(world, mask, next_tile, minute):
				# Short of the border, so that it stands in the tile it was in.
				_walk_skip(skip, target, maxf(until_border - 0.01, 0.0))
				skip.tiles_left = 0.0
				break
			_wear_entered_tile(world, mask, next_tile, target, npc.tile())
		_walk_skip(skip, target, steps)
		if npc.position == target:
			trip.next_index += 1
			trip.retries = 0
			if trip.next_index == trip.path.size():
				_finish_path(npc)
	for coords in skip.pinned:
		masks.unpin(coords)
	return true


## Lets the worker make the masks a skip waits for: `is_waiting` waits for it to finish what it is
## doing (a skip in one go, which has nothing else to do), else it only takes in what is done.
func make_masks(is_waiting: bool) -> void:
	_masks.update(is_waiting)


## Lets `delta` seconds pass for a villager with a trip. `fits` is a Callable `(npc, feet, map) ->
## bool` that says whether its body fits there. With `is_far_only`, every step is checked on
## the masks alone, loaded ground too.
func update(
	npc: Npc, delta: float, player_feet: Vector2, fits: Callable, is_far_only := false
) -> void:
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
			_walk(npc, delta, player_feet, fits, is_far_only)


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
## step is checked live, with the body (`fits`); elsewhere, far from the player (or everywhere with
## `is_far_only`, while the player is inside a building), only the tile it
## enters is checked, against the mask of its chunk at the time of entry (the tide, the season), and
## a tile whose mask is not there yet (an edit dropped it) is waited for. Both ways move towards the
## same tile centre at the same speed, so the position does not jump when a chunk loads or unloads
## between two centres. What is left of a frame's reach at a tile centre goes on along the next tile
## (through the same checks), so that a walker covers `walk_speed * delta` however long the frame.
func _walk(npc: Npc, delta: float, player_feet: Vector2, fits: Callable, is_far_only: bool) -> void:
	var trip := npc.trip
	if trip.pause_seconds > 0.0:
		trip.pause_seconds -= delta
		trip.state = NpcTrip.State.WAITING
		npc.activity = Npc.Activity.IDLE
		return
	var world := trip.map as World
	var reach := rules.behaviour("walk_speed") * delta
	for _tile in MAX_TILES_PER_UPDATE:
		var next_tile := trip.path[trip.next_index]
		var target := Vector2(next_tile) + Vector2(0.5, 0.5)
		var to_target := target - npc.position
		var distance := to_target.length()
		var is_arriving := distance <= reach
		var feet := target if is_arriving else npc.position + to_target * (reach / distance)
		if Npcs.is_crowding_player(
			npc.position, feet, player_feet, rules.behaviour("personal_space")
		):
			trip.state = NpcTrip.State.WAITING
			npc.activity = Npc.Activity.IDLE
			return
		if not is_far_only and _is_step_whole(world, feet, next_tile):
			if not fits.call(npc, feet, trip.map):
				_be_stuck(npc, delta)
				return
			Npcs.wear_step(trip.map, feet, npc.tile())
			Npcs.leave_footprint(trip.map, feet, npc.tile())
		elif not _may_enter_far_tile(npc, world, feet, delta):
			return
		trip.state = NpcTrip.State.WALKING
		trip.stuck_seconds = 0.0
		npc.position = feet
		if not to_target.is_zero_approx():
			npc.facing = Npc.facing_of(to_target)
			npc.heading = to_target.normalized()
		npc.activity = Npc.Activity.WALK
		if not is_arriving:
			break
		trip.next_index += 1
		trip.retries = 0
		if trip.next_index == trip.path.size():
			_finish_path(npc)
			return
		reach -= distance
		if reach <= 0.0:
			break


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
## anything, and wears it. A tile that is closed makes it stuck; one whose mask is being made
## makes it stand and wait, which is not being stuck.
func _may_enter_far_tile(npc: Npc, world: World, feet: Vector2, delta: float) -> bool:
	# The body is checked afresh when it is on loaded ground again.
	npc.free_body_tiles = Rect2i()
	var tile := Vector2i(feet.floor())
	if tile == npc.tile():
		return true
	var mask := _masks_of(world).mask_of(Chunk.world_to_chunk(tile))
	if mask == null:
		npc.activity = Npc.Activity.IDLE
		return false
	if not _is_tile_open(world, mask, tile, world.clock.total_minutes()):
		_be_stuck(npc, delta)
		return false
	_wear_entered_tile(world, mask, tile, feet, npc.tile())
	return true


## Whether a tile may be entered at the game minute `minutes`: no building on it, and the mask
## says it is free at the tide and in the season of that time.
static func _is_tile_open(world: World, mask: TravelMask, tile: Vector2i, minutes: int) -> bool:
	return (
		world.building_at(tile) == null
		and mask.is_free(Chunk.local_pos(tile), Tide.level(minutes), GameClock.day_of(minutes))
	)


## The tile a walker enters wears: a loaded one as the near step does, one that is not loaded where
## the mask says grass wears.
static func _wear_entered_tile(
	world: World, mask: TravelMask, tile: Vector2i, feet: Vector2, from_tile: Vector2i
) -> void:
	if world.is_chunk_loaded(Chunk.world_to_chunk(tile)):
		Npcs.wear_step(world, feet, from_tile)
	elif mask.wears(Chunk.local_pos(tile)):
		world.wear_unloaded(tile, PathRules.default_rules().villager_step())


## Moves a villager of a skip `tiles` towards `target`, which is on its path.
func _walk_skip(skip: NpcSkip, target: Vector2, tiles: float) -> void:
	var npc := skip.npc
	var to_target := target - npc.position
	if not to_target.is_zero_approx():
		npc.facing = Npc.facing_of(to_target)
		npc.heading = to_target.normalized()
	npc.position = npc.position.move_toward(target, tiles)
	npc.free_body_tiles = Rect2i()
	skip.tiles_left -= tiles
	skip.tiles_walked += tiles


## Asks for the masks of the next `skip_masks_ahead` chunks of the path (those the skip can reach)
## when the walker is in a new one, and pins them, and unpins what it has left behind: the masks it
## uses are never dropped for the limit, and the worker makes the next ones while it uses these.
func _ask_masks_ahead(skip: NpcSkip, masks: TravelMasks) -> void:
	var trip := skip.npc.trip
	var here := Chunk.world_to_chunk(trip.path[trip.next_index])
	if skip.asked_ahead_from == here:
		return
	skip.asked_ahead_from = here
	var ahead: Dictionary[Vector2i, bool] = {}
	var last := mini(trip.next_index + ceili(skip.tiles_left), trip.path.size() - 1)
	for index in range(trip.next_index, last + 1):
		ahead[Chunk.world_to_chunk(trip.path[index])] = true
		if ahead.size() == int(rules.travel("skip_masks_ahead")):
			break
	for coords in skip.pinned.keys():
		if not ahead.has(coords):
			masks.unpin(coords)
			skip.pinned.erase(coords)
	for coords in ahead:
		masks.pin(coords)
		masks.mask_of(coords)
		skip.pinned[coords] = true


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
