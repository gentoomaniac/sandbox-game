class_name MapBuilder
extends RefCounted
## The pictures of the chunks for the world map, built a chunk at a time and kept (see design/world/
## world-map.md). A chunk the world has loaded is painted from it; one it has not is generated on a
## worker thread, for the map only (nothing is added to the world), and painted when it is done.
## Painting reads the world, so it stays on the main thread, and costs 3 ms and more a chunk (more
## while the workers run); `update` paints a row of tiles at a time and stops when its time is up,
## so that opening the map never hitches.
##
## Each chunk keeps its clear picture, its foggy look and the texture of the two mixed by what the
## player has explored (see MapFog). A chunk's fog is made again when the exploration about it
## changed, and the picture of a chunk the world has loaded is made again by `refresh`.

## How many chunks are generated at once, on as many workers.
const JOBS_AT_ONCE := 2

var _world: World
var _exploration: Exploration
## The chunks built, by their coordinates.
var _built: Dictionary[Vector2i, BuiltChunk] = {}
var _jobs: Array[Job] = []
## The chunks the workers have generated, with the world's edits, that are not painted yet.
var _generated: Dictionary[Vector2i, Chunk] = {}
## The chunk being painted: it goes on from frame to frame.
var _painting: Painting


## What is kept of a chunk.
class BuiltChunk:
	extends RefCounted
	var clear: Image
	var foggy: Image
	## The clear and the foggy look mixed by the exploration, and its texture.
	var shown: Image
	var texture: ImageTexture
	## What `Exploration.revision_around` said when the texture was made.
	var fog_revision := -1
	## The world's chunk has changed since the picture was painted (see `refresh`).
	var is_stale := false


## A chunk generated on a worker: the worker writes only to its own job, which the main thread
## takes the result of once the task is done.
class Job:
	extends RefCounted
	var task_id: int
	var coords: Vector2i
	var chunk: Chunk


## A chunk that is being painted, row by row.
class Painting:
	extends RefCounted
	var coords: Vector2i
	var chunk: Chunk
	var image := MapColors.new_chunk_image()
	var next_row := 0


func _init(world: World, exploration: Exploration) -> void:
	_world = world
	_exploration = exploration
	# The workers only read what the generator needs from the rules, so they are loaded here.
	StationRules.default_rules()
	LandscapeRules.default_rules()
	WorldObjectTypes.TYPES.size()


func _notification(what: int) -> void:
	# The workers write to their jobs, which must outlive them.
	if what == NOTIFICATION_PREDELETE:
		for job in _jobs:
			WorkerThreadPool.wait_for_task_completion(job.task_id)


## The texture of a chunk, or null while it is not built.
func texture_of(coords: Vector2i) -> Texture2D:
	var built: BuiltChunk = _built.get(coords)
	return null if built == null else built.texture


## The picture the texture of a chunk has, or null while it is not built.
func image_of(coords: Vector2i) -> Image:
	var built: BuiltChunk = _built.get(coords)
	return null if built == null else built.shown


## The chunks built.
func built_count() -> int:
	return _built.size()


## Whether anything is being generated.
func is_generating() -> bool:
	return not _jobs.is_empty()


## The pictures of the chunks the world has loaded are made again from now on: they have changed
## since they were painted, perhaps. Until then the old ones are shown.
func refresh() -> void:
	for coords in _built:
		_built[coords].is_stale = _world.is_chunk_loaded(coords)


## Builds what the chunks of `wanted` (nearest the viewer first) lack: takes in the chunks the
## workers have generated, sets them to the next chunks to generate, and paints and mixes with the
## fog. It works until `budget_usec` microseconds have passed, but at least a row of tiles, so that
## it always gets on. Once a frame. Returns whether `wanted` is all built now.
func update(wanted: Array[Vector2i], budget_usec: int) -> bool:
	var started := Time.get_ticks_usec()
	for index in range(_jobs.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_jobs[index].task_id):
			_take(_jobs[index])
	if _painting != null and not _paint(started, budget_usec):
		return false
	var is_done := true
	for coords in wanted:
		if not World.is_chunk_in_bounds(coords):
			continue
		var built: BuiltChunk = _built.get(coords)
		if built != null and built.is_stale and not _world.is_chunk_loaded(coords):
			built.is_stale = false
		if built != null and not built.is_stale and _is_fog_current(coords, built):
			continue
		var chunk: Chunk = _generated.get(coords, _world.chunk_at(coords))
		if built == null and chunk == null:
			_start_generating(coords)
			is_done = false
		elif built == null or built.is_stale:
			_painting = Painting.new()
			_painting.coords = coords
			_painting.chunk = chunk
			if not _paint(started, budget_usec):
				return false
		else:
			_mix_fog(coords, built)
			if Time.get_ticks_usec() - started > budget_usec:
				return false
	return is_done


func _is_fog_current(coords: Vector2i, built: BuiltChunk) -> bool:
	return built.fog_revision == _exploration.revision_around(coords)


## Paints rows of the chunk in hand until the time is up. Returns whether it is all painted, and
## so built.
func _paint(started: int, budget_usec: int) -> bool:
	while _painting.next_row < Chunk.CHUNK_SIZE:
		MapColors.paint_row(_painting.image, _world, _painting.chunk, _painting.next_row)
		_painting.next_row += 1
		if Time.get_ticks_usec() - started > budget_usec:
			break
	if _painting.next_row < Chunk.CHUNK_SIZE:
		return false
	var coords := _painting.coords
	var built: BuiltChunk = _built.get(coords)
	if built == null:
		built = BuiltChunk.new()
		_built[coords] = built
	built.clear = _painting.image
	built.foggy = MapFog.foggy(built.clear)
	built.is_stale = false
	_generated.erase(coords)
	_painting = null
	_mix_fog(coords, built)
	return true


func _mix_fog(coords: Vector2i, built: BuiltChunk) -> void:
	built.shown = MapFog.apply(built.clear, built.foggy, _exploration, coords)
	if built.texture == null:
		built.texture = ImageTexture.create_from_image(built.shown)
	else:
		built.texture.update(built.shown)
	built.fog_revision = _exploration.revision_around(coords)


func _start_generating(coords: Vector2i) -> void:
	if (
		_jobs.size() == JOBS_AT_ONCE
		or _jobs.any(func(job: Job) -> bool: return job.coords == coords)
	):
		return
	var job := Job.new()
	job.coords = coords
	job.task_id = WorkerThreadPool.add_task(_generate.bind(weakref(job), _world.world_seed))
	_jobs.append(job)


## Runs on the worker, with a generator of its own.
func _generate(job_ref: WeakRef, world_seed: int) -> void:
	var job: Job = job_ref.get_ref()
	job.chunk = WorldGenerator.new(world_seed).generate_chunk(job.coords)


## Takes a generated chunk in, with the world's edits replayed on it.
func _take(job: Job) -> void:
	WorkerThreadPool.wait_for_task_completion(job.task_id)
	_jobs.erase(job)
	_world.replay_edits(job.chunk)
	_generated[job.coords] = job.chunk
