extends SceneTree
## Times GameState.collect_ground_items (the per-frame pile pick-up) over 600 frames on a save.
## godot --headless --path . -s tools/bench/pickup.gd -- <save file>

func _init() -> void:
	var state := SaveFile.read(OS.get_cmdline_user_args()[0])
	var t := Time.get_ticks_usec()
	for i in 600:
		state.collect_ground_items(1.0 / 60.0)
	print("collect_ground_items ms/frame ", (Time.get_ticks_usec() - t) / 600000.0, " piles ", state.world.ground_items.all().size())
	quit()
