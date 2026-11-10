extends SceneTree
## Renders the test piece with the game's prototype renderer (game/audio/module_renderer.gd) once
## through its order list, mono at 44.1 kHz, into <out dir>/test_reel.wav, for `check.py --against`
## to compare with libmodplug. `make music-check` runs both.
## godot --headless --path . -s tools/music/render.gd -- <out dir>

const MODULE := "res://assets/music/test_reel.mod"
## The loop and the fill: the piece's order list once.
const ROWS := 128 + 16


func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var module := TrackerModule.from_bytes(FileAccess.get_file_as_bytes(MODULE))
	var started := Time.get_ticks_usec()
	var stream := ModuleRenderer.new(module).render([Vector2i(0, ROWS)])
	print("rendered ", ROWS, " rows in ms ", (Time.get_ticks_usec() - started) / 1000.0)
	DirAccess.make_dir_recursive_absolute(out)
	stream.save_to_wav(out.path_join("test_reel.wav"))
	quit()
