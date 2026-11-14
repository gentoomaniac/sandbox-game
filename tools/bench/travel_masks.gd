extends SceneTree
## What the travel masks cost (#68, design/villagers/travel.md): for three seeds, the masks of a square
## of REGION x REGION chunks round the origin, asked for all at once and made frame after frame as the
## game would (`TravelMasks.update` once a frame, the worker generating meanwhile). Prints the median and
## the longest `update` on the main thread, the frames and the seconds it took, the cost of a stamp
## on its own (a mask from generated chunks, edits replayed), of generating a chunk on the main thread
## for comparison, and of one `is_free` question to a warm mask. Needs no save and writes nothing.
## godot --headless --path . -s tools/bench/travel_masks.gd

const SEEDS := [7, 42, 1]
const REGION := 9
const QUESTIONS := 100000


func _init() -> void:
	for world_seed: int in SEEDS:
		_bench(world_seed)
	quit()


func _bench(world_seed: int) -> void:
	var world := World.new(world_seed)
	var generator := WorldGenerator.new(world_seed)
	var first := Vector2i.ONE * (-REGION / 2)
	var coords: Array[Vector2i] = []
	for y in REGION:
		for x in REGION:
			coords.append(first + Vector2i(x, y))
	var generating: Array[float] = []
	var chunks := {}
	for chunk_coords in coords:
		var started := Time.get_ticks_usec()
		chunks[chunk_coords] = generator.generate_chunk(chunk_coords)
		generating.append((Time.get_ticks_usec() - started) / 1000.0)
	var stamping: Array[float] = []
	for chunk_coords in coords:
		var started := Time.get_ticks_usec()
		var neighbours: Array[Chunk] = []
		for step in [Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]:
			if chunks.has(chunk_coords + step):
				neighbours.append(chunks[chunk_coords + step].copy())
		var own: Chunk = chunks[chunk_coords].copy()
		world.replay_edits(own)
		TravelMask.new(own, neighbours, world.vegetation, world_seed)
		stamping.append((Time.get_ticks_usec() - started) / 1000.0)
	var masks := TravelMasks.new(world)
	for chunk_coords in coords:
		masks.mask_of(chunk_coords)
	var updates: Array[float] = []
	var frames_started := Time.get_ticks_usec()
	while masks.mask_coords().size() < coords.size():
		var started := Time.get_ticks_usec()
		masks.update()
		updates.append((Time.get_ticks_usec() - started) / 1000.0)
		# A frame of the game is 1/60 s; the worker runs while this one waits.
		OS.delay_usec(16667)
	var seconds := (Time.get_ticks_usec() - frames_started) / 1000000.0
	print(
		"seed %d, %d masks: generating a chunk on the main thread %s ms; a stamp %s ms; "
		% [world_seed, coords.size(), _stats(generating), _stats(stamping)],
		"%d frames of 16.7 ms (%.1f s) to make them, update %s ms; %s"
		% [updates.size(), seconds, _stats(updates), _question_time(masks, coords[0], world)]
	)


func _question_time(masks: TravelMasks, coords: Vector2i, world: World) -> String:
	var mask := masks.mask_of(coords)
	var tide_level := Tide.level(world.clock.total_minutes())
	var started := Time.get_ticks_usec()
	for question in QUESTIONS:
		mask.is_free(Vector2i(question % 32, question / 32 % 32), tide_level, 1)
	return "is_free %.2f us" % [float(Time.get_ticks_usec() - started) / QUESTIONS]


## The median and the most of the values.
static func _stats(values: Array[float]) -> String:
	var sorted := values.duplicate()
	sorted.sort()
	return "median %.2f, most %.2f" % [sorted[sorted.size() / 2], sorted.back()]
