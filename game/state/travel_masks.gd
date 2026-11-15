class_name TravelMasks
extends RefCounted
## The TravelMasks of the chunks of a World, made as they are asked for and kept in a least
## recently used cache (see design/villagers/travel.md).
##
## A mask is stamped from the generated chunks of its own chunk and the three before it (W, N and
## NW), with the world's edits replayed on copies of them. Generating is the dear part (about 9 ms
## a chunk): it goes on worker threads, a chunk to a job, each with a generator of its own. Those
## raw chunks are kept in a cache of their own and never get the edits, so an edit can not make one
## stale: only the masks go. Stamping a mask takes about 3 ms and is a job too, on copies of the raw
## chunks and a copy of the world's edits made on the main thread when it starts
## (`World.edits_snapshot`). Several jobs are in flight at once (`jobs_at_once`): a job is started
## and taken in a frame at the soonest, so one at a time would make 60 masks' worth of work a second
## at most. An edit that comes meanwhile bumps the version of its chunk, and a mask made from a
## chunk of another version is not published but made again: no mask is stale.
##
## How it all works: design/tech/pathfinding.md.

## The chunks a mask is stamped from, relative to its own: W, N and NW are those a big object
## reaches it from.
const SOURCE_STEPS: Array[Vector2i] = [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]

var _world: World
## What the worker takes of the world, kept here so that it reads nothing of the live World.
var _vegetation: Vegetation
var _world_seed: int
## The generators that are not in a job: a job takes one and gives it back when it is taken.
var _idle_generators: Array[WorldGenerator] = []
## Both caches hold the one used last at the end: a dictionary keeps the order its keys came in.
var _masks: Dictionary[Vector2i, TravelMask] = {}
var _raw_chunks: Dictionary[Vector2i, Chunk] = {}
## The chunks whose masks are asked for and not stamped yet, the oldest first: the keys of a
## dictionary, which keeps their order and answers `has` at once (searches ask all the time).
var _requested: Dictionary[Vector2i, bool] = {}
var _masks_kept: int
var _raw_chunks_kept: int
var _jobs_at_once: int
## The chunks whose masks a time skip is about to use, which the limit does not drop (see `pin`).
var _pinned: Dictionary[Vector2i, bool] = {}
## The jobs on the workers, the oldest first.
var _jobs: Array[Job] = []
## How many edits each chunk has had since the masks were made, to tell a mask made from chunks that
## were edited meanwhile.
var _edit_versions: Dictionary[Vector2i, int] = {}


## One piece of work on a worker: a chunk generated, or a mask stamped. The worker writes only to
## its own job, which the main thread takes the result of once the task is done. The task is given
## a WeakRef to it: with the job bound directly, the engine was observed to crash at exit (the cause
## is not established; the destructor waits for every task in flight either way).
class Job:
	extends RefCounted
	var task_id: int
	## The chunk it generates, or the chunk whose mask it stamps.
	var coords: Vector2i
	var is_stamping: bool
	## Of a generating job: the generator it uses alone (null until the worker makes one), and the
	## chunk it made.
	var generator: WorldGenerator
	var chunk: Chunk
	## Of a stamping job: the edit versions of the chunks it is made from, and the mask.
	var versions: Dictionary[Vector2i, int] = {}
	var mask: TravelMask


## `masks_kept` and `raw_chunks_kept` are how many masks and generated chunks are kept (the least
## recently used go first), `jobs_at_once` how many jobs the workers have in flight; see
## `for_world`.
func _init(world: World, masks_kept: int, raw_chunks_kept: int, jobs_at_once := 1) -> void:
	# A mask needs four raw chunks, which must stay until it is stamped.
	assert(raw_chunks_kept >= 4, "Too few raw chunks kept for a mask")
	_world = world
	_vegetation = world.vegetation
	_world_seed = world.world_seed
	_masks_kept = masks_kept
	_raw_chunks_kept = raw_chunks_kept
	_jobs_at_once = jobs_at_once
	# The worker only reads what the generator needs from the rules, so they are loaded here.
	StationRules.default_rules()
	LandscapeRules.default_rules()
	WorldObjectTypes.TYPES.size()
	world.edited.connect(_drop_masks_reached_by_edit)


## The masks of `world`, as many kept as the rules say ([travel] of data/npcs.cfg).
static func for_world(world: World, rules := NpcRules.default_rules()) -> TravelMasks:
	return TravelMasks.new(
		world,
		int(rules.travel("far_masks_kept")),
		int(rules.travel("far_chunks_kept")),
		int(rules.travel("far_mask_jobs"))
	)


func _notification(what: int) -> void:
	# The workers write to their jobs, which must outlive them.
	if what == NOTIFICATION_PREDELETE:
		for job in _jobs:
			WorkerThreadPool.wait_for_task_completion(job.task_id)


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


## Keeps the mask of `coords`, once made, from being dropped by the limit, until `unpin`. A skip
## pins the masks of the way ahead of a trip, which it asked for a few at a time: more may be kept
## than the limit says, for as long as they are pinned.
func pin(coords: Vector2i) -> void:
	_pinned[coords] = true


func unpin(coords: Vector2i) -> void:
	_pinned.erase(coords)


## The mask of a chunk if it is made, or null, without asking for it (see `mask_of`).
func made_mask(coords: Vector2i) -> TravelMask:
	return _masks.get(coords)


## Takes in what the workers have done: generated chunks, and masks, which are published if no edit
## has come to the chunks they were made from meanwhile, and else made again. Then sets the workers
## to new jobs, up to `jobs_at_once`: stamping the asked-for masks whose chunks are all there, the
## oldest first, and then generating the chunks the oldest still lack. Once a frame. With
## `is_waiting` it first waits for the oldest job to finish, for whoever has nothing else to do.
func update(is_waiting := false) -> void:
	if is_waiting and not _jobs.is_empty():
		_take(_jobs[0])
	# Backwards, as `_take` takes the job out of the array.
	for index in range(_jobs.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_jobs[index].task_id):
			_take(_jobs[index])
	for coords in _requested:
		if _jobs.size() == _jobs_at_once:
			return
		if _first_missing_raw_chunk(coords) == null and not _has_job(coords, true):
			_start_stamping(coords)
	for coords in _requested:
		for step in SOURCE_STEPS:
			var needed := coords + step
			if _jobs.size() == _jobs_at_once:
				return
			if (
				World.is_chunk_in_bounds(needed)
				and not _raw_chunks.has(needed)
				and not _has_job(needed, false)
			):
				_start_generating(needed)


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


## Whether a job is stamping the mask of `coords` (`is_stamping`) or generating the chunk.
func _has_job(coords: Vector2i, is_stamping: bool) -> bool:
	for job in _jobs:
		if job.coords == coords and job.is_stamping == is_stamping:
			return true
	return false


## Runs on the worker, which also makes a generator when there was none idle: that is the main
## thread's few milliseconds spared.
func _generate(job_ref: WeakRef) -> void:
	var job: Job = job_ref.get_ref()
	if job.generator == null:
		job.generator = WorldGenerator.new(_world_seed)
	job.chunk = job.generator.generate_chunk(job.coords)


## Runs on the worker: the mask of the job's chunk from copies of its raw chunks (own first) with
## the edits of the snapshot replayed on them. It touches nothing the main thread writes: the raw
## chunks are never changed, and the snapshot is its own.
func _stamp(job_ref: WeakRef, raw: Array[Chunk], snapshots: Array[Dictionary]) -> void:
	var job: Job = job_ref.get_ref()
	var own: Chunk
	var neighbours: Array[Chunk] = []
	for index in raw.size():
		var chunk := raw[index].copy()
		World.replay_snapshot(chunk, snapshots[index])
		if chunk.coords == job.coords:
			own = chunk
		else:
			neighbours.append(chunk)
	job.mask = TravelMask.new(own, neighbours, _vegetation, _world_seed)


func _start_generating(coords: Vector2i) -> void:
	var job := Job.new()
	job.coords = coords
	if not _idle_generators.is_empty():
		job.generator = _idle_generators.pop_back()
	job.task_id = WorkerThreadPool.add_task(_generate.bind(weakref(job)))
	_jobs.append(job)


## Starts a job on the mask of `coords`, whose raw chunks are all there. The edits are copied here,
## on the main thread, with the versions they are of.
func _start_stamping(coords: Vector2i) -> void:
	var job := Job.new()
	job.coords = coords
	job.is_stamping = true
	var raw: Array[Chunk] = []
	var snapshots: Array[Dictionary] = []
	for needed in chunks_for(coords):
		var chunk := _raw_chunks[needed]
		_raw_chunks.erase(needed)
		_raw_chunks[needed] = chunk
		raw.append(chunk)
		snapshots.append(_world.edits_snapshot(needed))
		job.versions[needed] = _edit_versions.get(needed, 0)
	job.task_id = WorkerThreadPool.add_task(_stamp.bind(weakref(job), raw, snapshots))
	_jobs.append(job)


## How many jobs are in flight (for the tests).
func job_count() -> int:
	return _jobs.size()


## Whether a worker is making a mask (for the tests of an edit meanwhile).
func is_stamping() -> bool:
	return _jobs.any(func(job: Job) -> bool: return job.is_stamping)


func _take(job: Job) -> void:
	WorkerThreadPool.wait_for_task_completion(job.task_id)
	_jobs.erase(job)
	if job.is_stamping:
		_publish_stamped(job)
	else:
		_keep_generated(job)


func _keep_generated(job: Job) -> void:
	_raw_chunks[job.coords] = job.chunk
	_idle_generators.append(job.generator)
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
func _publish_stamped(job: Job) -> void:
	for needed in job.versions:
		if _edit_versions.get(needed, 0) != job.versions[needed]:
			return
	_requested.erase(job.coords)
	_masks[job.coords] = job.mask
	for kept in _masks.keys():
		if _masks.size() <= _masks_kept:
			break
		if not _pinned.has(kept):
			_masks.erase(kept)
