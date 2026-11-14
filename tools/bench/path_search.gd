extends SceneTree
## How long PathSearch takes for each tile it looks at, over the real world: searches between
## random tiles a few dozen tiles apart in the generated chunks around a new game's start, with the
## step rule of the villagers (`Npcs.can_stand_at`) and a cost of 1.0 a tile. Prints the tiles
## looked at and the microseconds for each, over all searches that found a way or a leg. It sets
## `max_nodes` and the budget of a frame (see `[travel]` of data/npcs.cfg). Needs no save and
## writes nothing.
## godot --headless --path . -s tools/bench/path_search.gd [-- --seed=<n>]

const CHUNK_RADIUS := 3
const SEARCHES := 100
const DISTANCE := Vector2i(60, 40)


func _process(_delta: float) -> bool:
	var world_seed := 7
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			world_seed = int(argument.trim_prefix("--seed="))
	var state := GameState.new_game(world_seed)
	var world := state.world
	var generator := WorldGenerator.new(world_seed)
	var centre := state.player.tile()
	for y in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for x in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			var coords := Chunk.world_to_chunk(centre) + Vector2i(x, y)
			if not world.is_chunk_loaded(coords):
				world.add_chunk(generator.generate_chunk(coords))
	var is_free := func(tile: Vector2i) -> bool:
		return Npcs.can_stand_at(world, Vector2(tile) + Vector2(0.5, 0.5))
	var cost_of := func(_tile: Vector2i) -> float: return 1.0
	var max_nodes := int(NpcRules.default_rules().travel("max_nodes"))
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var nodes := 0
	var microseconds := 0
	var outcomes := {}
	for _search in SEARCHES:
		var start := centre + Vector2i(rng.randi_range(-30, 30), rng.randi_range(-30, 30))
		var goal := (
			start
			+ Vector2i(
				rng.randi_range(-DISTANCE.x, DISTANCE.x), rng.randi_range(-DISTANCE.y, DISTANCE.y)
			)
		)
		var started := Time.get_ticks_usec()
		var search := PathSearch.new(start, goal, is_free, cost_of, max_nodes)
		search.step(max_nodes)
		microseconds += Time.get_ticks_usec() - started
		nodes += search.nodes_looked_at
		outcomes[search.state] = outcomes.get(search.state, 0) + 1
	print(
		"searches ",
		SEARCHES,
		" outcomes ",
		outcomes,
		" tiles looked at ",
		nodes,
		" microseconds ",
		microseconds,
		" per tile ",
		float(microseconds) / maxi(nodes, 1)
	)
	quit()
	return true
