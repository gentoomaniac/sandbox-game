class_name TravelMasks
extends RefCounted
## The TravelMasks of the chunks of a World, made as they are asked for and kept in a least
## recently used cache (see design/villagers/travel.md).
##
## A mask is stamped from the generated chunks of its own chunk and the three before it (W, N and
## NW), with the world's edits replayed on copies of them. Generating is the dear part (about 9 ms
## a chunk): it goes on a worker thread, one chunk at a time, with a generator of its own. Those raw
## chunks are kept in a cache of their own and never get the edits, so an edit can not make one
## stale: only the masks go. Stamping a mask takes about 3 ms and is done on the worker too, on
## copies of the raw chunks and a copy of the world's edits made on the main thread when it starts
## (`World.edits_snapshot`). An edit that comes meanwhile bumps the version of its chunk, and a mask
## made from a chunk of another version is not published but made again: no mask is stale.

## The chunks a mask is stamped from, relative to its own: W, N and NW are those a big object
## reaches it from.
const SOURCE_STEPS: Array[Vector2i] = [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]

var _world: World
var _generator: WorldGenerator
## Both caches hold the one used last at the end: a dictionary keeps the order its keys came in.
var _masks: Dictionary[Vector2i, TravelMask] = {}
var _raw_chunks: Dictionary[Vector2i, Chunk] = {}
## The chunks whose masks are asked for and not stamped yet, the oldest first: the keys of a
## dictionary, which keeps their order and answers `has` at once (searches ask all the time).
var _requested: Dictionary[Vector2i, bool] = {}
var _masks_kept: int
var _raw_chunks_kept: int
## The worker's task (-1 while it has none) and what it makes: a chunk, or the mask of `_stamping`
## (null when it generates) made from chunks of the edit versions in `_stamping_versions`.
var _task_id := -1
var _generated: Chunk
var _stamping: Variant
var _stamped: TravelMask
var _stamping_versions: Dictionary = {}
## How many edits each chunk has had since the masks were made, to tell a mask made from chunks that
## were edited meanwhile.
var _edit_versions: Dictionary[Vector2i, int] = {}


## `masks_kept` and `raw_chunks_kept` are how many masks and generated chunks are kept (the least
## recently used go first); see `for_world`.
func _init(world: World, masks_kept: int, raw_chunks_kept: int) -> void:
	# A mask needs four raw chunks, which must stay until it is stamped.
	assert(raw_chunks_kept >= 4, "Too few raw chunks kept for a mask")
	_world = world
	_masks_kept = masks_kept
	_raw_chunks_kept = raw_chunks_kept
	_generator = WorldGenerator.new(world.world_seed)
	# The worker only reads what the generator needs from the rules, so they are loaded here.
	StationRules.default_rules()
	LandscapeRules.default_rules()
	WorldObjectTypes.TYPES.size()
	world.edited.connect(_drop_masks_reached_by_edit)


## The masks of `world`, as many kept as the rules say ([travel] of data/npcs.cfg).
static func for_world(world: World, rules := NpcRules.default_rules()) -> TravelMasks:
	return TravelMasks.new(
		world, int(rules.travel("far_masks_kept")), int(rules.travel("far_chunks_kept"))
	)


func _notification(what: int) -> void:
	# The worker writes to this object, which must outlive it.
	if what == NOTIFICATION_PREDELETE and _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)


## The mask of a chunk, or null if it is not stamped yet: it is then asked for, and `update` makes
## it. Null for a chunk outside the world.
func mask_of(coords: Vector2i) -> TravelMask:
	if not World.is_chunk_in_bounds(coords):
		return null
	var mask: TravelMask = _masks.get(coords)
	if mask != null:
		_masks.erase(coords)
		_masks[coords] = mask
	else:
		_requested[coords] = true
	return mask


## Takes in what the worker has done: a generated chunk, or a mask, which is published if no edit
## has come to the chunks it was made from meanwhile, and else made again. Then sets the worker to
## its next job: stamping the oldest asked-for mask whose chunks are all there, or else generating
## the chunk the oldest still lacks. Once a frame. With `is_waiting` it first waits for the worker
## to finish, for whoever has nothing else to do.
func update(is_waiting := false) -> void:
	_take_result(is_waiting)
	if _task_id >= 0:
		return
	for coords in _requested:
		if _first_missing_raw_chunk(coords) == null:
			_start_stamping(coords)
			return
	for coords in _requested:
		var missing: Variant = _first_missing_raw_chunk(coords)
		if missing != null:
			_task_id = WorkerThreadPool.add_task(_generate.bind(missing))
			return


## The mask of a chunk once the worker has made what it needs, or null for a chunk outside the
## world. For a time skip, and for tests.
func wait_for_mask(coords: Vector2i) -> TravelMask:
	while World.is_chunk_in_bounds(coords) and mask_of(coords) == null:
		update(true)
	return mask_of(coords)


## The chunks whose masks are stamped.
func mask_coords() -> Array[Vector2i]:
	return _masks.keys()


## The chunks whose raw chunks are kept.
func raw_chunk_coords() -> Array[Vector2i]:
	return _raw_chunks.keys()


## The generated chunk, as the generator made it (no edits), or null if it is not kept.
func raw_chunk(coords: Vector2i) -> Chunk:
	return _raw_chunks.get(coords)


## The chunks a mask is stamped from: its own and W, N and NW of it, those inside the world.
static func chunks_for(coords: Vector2i) -> Array[Vector2i]:
	var needed: Array[Vector2i] = []
	for step in SOURCE_STEPS:
		if World.is_chunk_in_bounds(coords + step):
			needed.append(coords + step)
	return needed


## An edit in a chunk changes its own mask and those of the chunks big objects of it reach into:
## E, S and SE.
func _drop_masks_reached_by_edit(edited_coords: Vector2i) -> void:
	_edit_versions[edited_coords] = _edit_versions.get(edited_coords, 0) + 1
	for step in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		_masks.erase(edited_coords + step)


## The first of the chunks a mask is stamped from that is not generated yet, or null. Asked of every
## request every frame, so it makes nothing.
func _first_missing_raw_chunk(coords: Vector2i) -> Variant:
	for step in SOURCE_STEPS:
		var needed := coords + step
		if World.is_chunk_in_bounds(needed) and not _raw_chunks.has(needed):
			return needed
	return null


## Runs on the worker.
func _generate(coords: Vector2i) -> void:
	_generated = _generator.generate_chunk(coords)


## Runs on the worker: the mask of `coords` from copies of its raw chunks (own first) with the
## edits of the snapshot replayed on them. It touches nothing the main thread writes: the raw chunks
## are never changed, and the snapshot is its own.
func _stamp(coords: Vector2i, raw: Array[Chunk], snapshots: Array[Dictionary]) -> void:
	var own: Chunk
	var neighbours: Array[Chunk] = []
	for index in raw.size():
		var chunk := raw[index].copy()
		World.replay_snapshot(chunk, snapshots[index])
		if chunk.coords == coords:
			own = chunk
		else:
			neighbours.append(chunk)
	_stamped = TravelMask.new(own, neighbours, _world.vegetation, _world.world_seed)


## Starts the worker on the mask of `coords`, whose raw chunks are all there. The edits are copied
## here, on the main thread, with the versions they are of.
func _start_stamping(coords: Vector2i) -> void:
	var raw: Array[Chunk] = []
	var snapshots: Array[Dictionary] = []
	_stamping_versions = {}
	for needed in chunks_for(coords):
		var chunk := _raw_chunks[needed]
		_raw_chunks.erase(needed)
		_raw_chunks[needed] = chunk
		raw.append(chunk)
		snapshots.append(_world.edits_snapshot(needed))
		_stamping_versions[needed] = _edit_versions.get(needed, 0)
	_stamping = coords
	_task_id = WorkerThreadPool.add_task(_stamp.bind(coords, raw, snapshots))


## Whether the worker is making a mask (for the tests of an edit meanwhile).
func is_stamping() -> bool:
	return _task_id >= 0 and _stamping != null


func _take_result(is_waiting: bool) -> void:
	if _task_id < 0 or not (is_waiting or WorkerThreadPool.is_task_completed(_task_id)):
		return
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	if _stamping != null:
		_publish_stamped()
	else:
		_keep_generated()


func _keep_generated() -> void:
	_raw_chunks[_generated.coords] = _generated
	_generated = null
	# What an asked-for mask still needs is kept, whatever the limit.
	var needed := {}
	for coords in _requested:
		for step in SOURCE_STEPS:
			needed[coords + step] = true
	for coords in _raw_chunks.keys():
		if _raw_chunks.size() <= _raw_chunks_kept:
			break
		if not needed.has(coords):
			_raw_chunks.erase(coords)


## A mask made from chunks that were edited meanwhile is dropped, and its chunk is still asked for.
func _publish_stamped() -> void:
	var coords: Vector2i = _stamping
	var mask := _stamped
	var is_stale := false
	for needed: Vector2i in _stamping_versions:
		is_stale = is_stale or _edit_versions.get(needed, 0) != _stamping_versions[needed]
	_stamping = null
	_stamped = null
	if is_stale:
		return
	_requested.erase(coords)
	_masks[coords] = mask
	while _masks.size() > _masks_kept:
		_masks.erase(_masks.keys()[0])
