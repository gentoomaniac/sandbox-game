extends SceneTree
## Times what a save costs on a save: the snapshot of the game, the part of a timed or quick save
## that stops the main thread, and the save data and JSON text made of it, which a worker thread
## makes (the same two together are what quitting and the pause menu's save take at once).
## godot --headless --path . -s tools/bench/save.gd -- <save file>

const RUNS := 5


func _init() -> void:
	var state := SaveFile.read(OS.get_cmdline_user_args()[0])
	var snapshot_usec := 0
	var text_usec := 0
	for run in RUNS:
		var started := Time.get_ticks_usec()
		var snapshot := SaveFile.snapshot(state)
		var snapshotted := Time.get_ticks_usec()
		SaveFile.text_of(snapshot)
		snapshot_usec += snapshotted - started
		text_usec += Time.get_ticks_usec() - snapshotted
	print(
		"save ms: snapshot (main thread) ",
		snapshot_usec / (1000.0 * RUNS),
		", text (worker) ",
		text_usec / (1000.0 * RUNS)
	)
	quit()
