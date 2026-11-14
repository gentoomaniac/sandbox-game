class_name TravelMasks
extends RefCounted
## The TravelMasks of the chunks of a World, made as they are asked for and kept in a least
## recently used cache (see design/villagers/travel.md).
##
## A mask is stamped from the generated chunks of its own chunk and the three before it (W, N and
## NW), with the world's edits replayed on copies of them. Generating is the dear part (about 9 ms
## a chunk): it goes on a worker thread, one chunk at a time, with a generator of its own. Those raw
## chunks are kept in a cache of their own and never get the edits, so an edit can not make one
## stale: only the masks go. Stamping a mask takes about 2 ms and is done on the main thread, one
## in each `update`; as it reads the edits as it stamps, no mask is stamped stale.

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
## The worker's task (-1 while it has none) and the chunk it makes.
var _task_id := -1
var _generated: Chunk


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


## Takes in what the worker has generated, stamps the oldest asked-for mask whose chunks are all
## there (one at most), and sets the worker to the chunk the oldest still lacks. Once a frame.
## With `is_waiting` it first waits for the worker to finish, for whoever has nothing else to do.
func update(is_waiting := false) -> void:
	_take_generated_chunk(is_waiting)
	for coords in _requested:
		if _first_missing_raw_chunk(coords) == null:
			_requested.erase(coords)
			_stamp(coords)
			break
	if _task_id >= 0:
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


func _take_generated_chunk(is_waiting: bool) -> void:
	if _task_id < 0 or not (is_waiting or WorkerThreadPool.is_task_completed(_task_id)):
		return
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
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


func _stamp(coords: Vector2i) -> void:
	var own: Chunk
	var neighbours: Array[Chunk] = []
	for needed in chunks_for(coords):
		var raw := _raw_chunks[needed]
		_raw_chunks.erase(needed)
		_raw_chunks[needed] = raw
		var chunk := raw.copy()
		_world.replay_edits(chunk)
		if needed == coords:
			own = chunk
		else:
			neighbours.append(chunk)
	_masks[coords] = TravelMask.new(own, neighbours, _world.vegetation, _world.world_seed)
	while _masks.size() > _masks_kept:
		_masks.erase(_masks.keys()[0])
