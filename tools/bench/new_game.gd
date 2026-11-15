extends SceneTree
## Times a new game with and without the village Wehlsbüll with its villagers (#9), and the size of
## the save of each, for a few seeds: how much the village costs the start of a game and the save.
## godot --headless --path . -s tools/bench/new_game.gd [-- --seeds=1,7,20] (set XDG_DATA_HOME away
## from the real one)

const SEEDS := [1, 7, 20]
const RUNS := 3


func _init() -> void:
	var seeds := SEEDS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="):
			seeds = []
			for word in argument.trim_prefix("--seeds=").split(","):
				seeds.append(int(word))
	for world_seed: int in seeds:
		var bare := _measure(world_seed, false)
		var with_village := _measure(world_seed, true)
		print(
			"seed %d: new game %.0f ms bare, %.0f ms with the village; save %.0f KB bare, %.0f KB with"
			% [world_seed, bare[0], with_village[0], bare[1], with_village[1]]
		)
	quit()


## The milliseconds a new game takes (the best of RUNS) and the kilobytes of its save.
func _measure(world_seed: int, with_village: bool) -> Array[float]:
	var best_msec := INF
	var state: GameState
	for _run in RUNS:
		var started := Time.get_ticks_usec()
		state = GameState.new_game(world_seed, with_village)
		best_msec = minf(best_msec, (Time.get_ticks_usec() - started) / 1000.0)
	var save_bytes := SaveFile.text_of(SaveFile.snapshot(state)).length()
	return [best_msec, save_bytes / 1024.0]
