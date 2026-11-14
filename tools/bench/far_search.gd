extends SceneTree
## What a search over masks costs (#68, design/villagers/travel.md): for three seeds, ways of about
## 300 tiles between random tiles a villager can stand on, in a square of REGION x REGION chunks
## whose masks are all made first (warm). Each way is searched as a trip does, in legs of
## `max_nodes` tiles (data/npcs.cfg) until it is found or fails. Prints, over the ways: the tiles
## looked at and the milliseconds of searching for a way that is found (median and most), the microseconds a tile
## costs, and how many ways were found; first with no chunk loaded (the far view: masks and
## waiting), then with all the chunks loaded (the live view), for comparison. Needs no save and
## writes nothing.
## godot --headless --path . -s tools/bench/far_search.gd

const SEEDS := [7, 42, 1]
const REGION := 15
const WAYS := 60
const REACH := Vector2i(210, 90)
const MOST_LEGS := 20


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
	var view := TravelView.new(world, masks, rules, world.clock.total_minutes())
	var ways := _pick_ways(world_seed, view, first)
	print("  far:  ", _search_all(ways, view, masks, rules))
	var generator := WorldGenerator.new(world_seed)
	for y in range(first.y - 1, first.y + REGION):
		for x in range(first.x - 1, first.x + REGION):
			world.add_chunk(generator.generate_chunk(Vector2i(x, y)))
	view = TravelView.new(world, masks, rules, world.clock.total_minutes())
	print("  live: ", _search_all(ways, view, masks, rules))


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
		var goal := start + Vector2i(
			REACH.x * (1 if rng.randf() < 0.5 else -1), REACH.y * (1 if rng.randf() < 0.5 else -1)
		)
		var is_inside := goal.x >= low.x and goal.x <= high.x and goal.y >= low.y and goal.y <= high.y
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
			var search := PathSearch.new(
				start,
				way[1],
				view.is_free,
				view.cost_of,
				int(rules.travel("max_nodes")),
				rules.travel("heuristic_weight"),
				view.is_known
			)
			while not search.is_over():
				search.step(1000000)
				if search.state == PathSearch.State.WAITING:
					# A way that strays out of the region: the making of a mask is not searching.
					var waiting_started := Time.get_ticks_usec()
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


## The median and the most of the values.
static func _stats(values: Array[float]) -> String:
	var sorted := values.duplicate()
	sorted.sort()
	return "median %.1f, most %.1f" % [sorted[sorted.size() / 2], sorted.back()]
