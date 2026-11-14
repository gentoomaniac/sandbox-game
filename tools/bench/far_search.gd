extends SceneTree
## What searches over the travel masks cost (#68, design/tech/pathfinding.md), for three seeds, over
## ways of about 300 tiles between random tiles a villager can stand on, in a square of REGION x
## REGION chunks:
## 1. the cost of the search itself, on this thread, with all the masks made (warm): tiles looked at
##    and milliseconds for the ways that are found, and the microseconds a tile;
## 2. thirty villagers leaving at once, each search a task of the Pathfinder (`search_tasks` of
##    data/npcs.cfg), at 60 frames a second: how long until the first and the last way is found
##    with the masks warm and with them cold (made as the searches ask), and what the main thread
##    spends in a frame (`TravelMasks.update` and `Pathfinder.tick`).
## Needs no save and writes nothing. Run it with `taskset` to see what few cores do.
## godot --headless --path . -s tools/bench/far_search.gd

const SEEDS := [7, 42, 1]
const REGION := 15
const WAYS := 60
const REACH := Vector2i(210, 90)
const MOST_LEGS := 20
const DEPARTURES := 30
const FRAME_USEC := 16667


func _init() -> void:
	for world_seed: int in SEEDS:
		_bench(world_seed)
	quit()


func _bench(world_seed: int) -> void:
	var rules := NpcRules.default_rules()
	var world := World.new(world_seed)
	var masks := TravelMasks.for_world(world, rules)
	var first := Vector2i.ONE * (-REGION / 2)
	var warming_started := Time.get_ticks_usec()
	for y in REGION:
		for x in REGION:
			masks.wait_for_mask(first + Vector2i(x, y))
	print(
		"seed %d: %d masks made in %.1f s"
		% [world_seed, masks.mask_coords().size(), (Time.get_ticks_usec() - warming_started) / 1e6]
	)
	var snapshot := TravelSnapshot.of(world, 0)
	var view := TravelView.new(snapshot, rules, world.clock.total_minutes())
	_provide_all(view, masks, first)
	var ways := _pick_ways(world_seed, view, first)
	print("  on this thread: ", _search_all(ways, view, masks, rules))
	print("  30 leaving, masks warm: ", _depart(ways, world, masks, snapshot, rules))
	var cold := TravelMasks.for_world(world, rules)
	print("  30 leaving, masks cold: ", _depart(ways, world, cold, snapshot, rules))


## Gives the view the mask of every chunk of the region.
func _provide_all(view: TravelView, masks: TravelMasks, first: Vector2i) -> void:
	for y in REGION:
		for x in REGION:
			var coords := first + Vector2i(x, y)
			view.is_known(Chunk.to_world(coords, Vector2i.ZERO))
	while not view.provide(masks):
		masks.update(true)


## Pairs of tiles a villager can stand on, REACH apart in a random direction, inside the region.
func _pick_ways(world_seed: int, view: TravelView, first: Vector2i) -> Array[Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	# Three chunks in from the edge, so that the ways stay in the region of the masks.
	var margin := Vector2i.ONE * 3 * Chunk.CHUNK_SIZE
	var low := first * Chunk.CHUNK_SIZE + margin
	var high := (first + Vector2i.ONE * REGION) * Chunk.CHUNK_SIZE - margin
	var ways: Array[Array] = []
	while ways.size() < WAYS:
		var start := Vector2i(rng.randi_range(low.x, high.x), rng.randi_range(low.y, high.y))
		var sign_x := 1 if rng.randf() < 0.5 else -1
		var sign_y := 1 if rng.randf() < 0.5 else -1
		var goal := start + Vector2i(REACH.x * sign_x, REACH.y * sign_y)
		var is_inside := (
			goal.x >= low.x and goal.x <= high.x and goal.y >= low.y and goal.y <= high.y
		)
		if is_inside and view.is_free(start) and view.is_free(goal):
			ways.append([start, goal])
	return ways


func _search_all(
	ways: Array[Array], view: TravelView, masks: TravelMasks, rules: NpcRules
) -> String:
	var milliseconds: Array[float] = []
	var nodes: Array[float] = []
	var found := 0
	var total_nodes := 0
	var total_usec := 0
	var waits := 0
	for way in ways:
		var start: Vector2i = way[0]
		var usec := 0
		var looked_at := 0
		var is_found := false
		for _leg in MOST_LEGS:
			var started := Time.get_ticks_usec()
			var paused := 0
			var search := _new_search(start, way[1], view, rules)
			while not search.is_over():
				search.step(1000000)
				if search.state == PathSearch.State.WAITING:
					# A way that strays out of the region: the making of a mask is not searching.
					var waiting_started := Time.get_ticks_usec()
					while not view.provide(masks):
						masks.update(true)
					paused += Time.get_ticks_usec() - waiting_started
					waits += 1
			usec += Time.get_ticks_usec() - started - paused
			looked_at += search.nodes_looked_at
			if search.state == PathSearch.State.FOUND:
				is_found = true
				break
			if search.state == PathSearch.State.FAILED:
				break
			start = search.path.back()
		found += 1 if is_found else 0
		# A way that is not there is searched all over: it says nothing of what a way costs.
		if is_found:
			milliseconds.append(usec / 1000.0)
			nodes.append(looked_at)
		total_nodes += looked_at
		total_usec += usec
	return (
		"%d of %d ways found; of those, tiles looked at %s, ms %s; all together %.2f us a tile; waited %d times"
		% [
			found,
			ways.size(),
			_stats(nodes),
			_stats(milliseconds),
			float(total_usec) / total_nodes,
			waits
		]
	)


func _new_search(start: Vector2i, goal: Vector2i, view: TravelView, rules: NpcRules) -> PathSearch:
	return PathSearch.new(
		start,
		goal,
		view.is_free,
		view.cost_of,
		int(rules.travel("max_nodes")),
		rules.travel("heuristic_weight"),
		view.is_known
	)


## DEPARTURES villagers leave at once, each with a view of its own over `masks`. Frames of 16.7 ms
## go by (`masks.update` and `pathfinder.tick` are the main thread's share, timed) until every
## search is over.
func _depart(
	ways: Array[Array], world: World, masks: TravelMasks, snapshot: TravelSnapshot, rules: NpcRules
) -> String:
	var pathfinder := Pathfinder.new(int(rules.travel("search_tasks")))
	var searches: Array[PathSearch] = []
	for index in DEPARTURES:
		var view := TravelView.new(snapshot, rules, world.clock.total_minutes())
		var way: Array = ways[index % ways.size()]
		view.prefetch(masks, way[0], way[1])
		var search := _new_search(way[0], way[1], view, rules)
		searches.append(search)
		pathfinder.queue(search, func() -> bool: return view.provide(masks))
	var started := Time.get_ticks_usec()
	var done_at: Array[float] = []
	var finished := {}
	var frames: Array[float] = []
	while finished.size() < searches.size():
		var frame_started := Time.get_ticks_usec()
		masks.update()
		pathfinder.tick()
		frames.append((Time.get_ticks_usec() - frame_started) / 1000.0)
		for search in searches:
			if pathfinder.is_finished(search) and not finished.has(search):
				finished[search] = true
				done_at.append((Time.get_ticks_usec() - started) / 1e6)
		OS.delay_usec(FRAME_USEC)
	return (
		"first done after %.2f s, median %.2f s, last %.2f s; main thread a frame: median %.2f ms, most %.2f ms"
		% [
			done_at[0],
			done_at[done_at.size() / 2],
			done_at[-1],
			_median(frames),
			frames.max()
		]
	)


func _median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


## The median and the most of the values.
static func _stats(values: Array[float]) -> String:
	var sorted := values.duplicate()
	sorted.sort()
	return "median %.1f, most %.1f" % [sorted[sorted.size() / 2], sorted.back()]
