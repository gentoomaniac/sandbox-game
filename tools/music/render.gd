extends SceneTree
## Renders every piece of assets/music/ with the game's prototype renderer
## (game/audio/module_renderer.gd) once through its order list, mono at 44.1 kHz, into
## <out dir>/<piece>.wav, for `check.py --against` to compare with libmodplug. `make music-check`
## runs both.
## godot --headless --path . -s tools/music/render.gd -- <out dir>

const MUSIC := "res://assets/music"


func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	for file in DirAccess.get_files_at(MUSIC):
		if file.get_extension() != "mod":
			continue
		var module := TrackerModule.from_bytes(FileAccess.get_file_as_bytes(MUSIC.path_join(file)))
		var renderer := ModuleRenderer.new(module)
		var rows := renderer.rows_once_through()
		var started := Time.get_ticks_usec()
		var stream := renderer.render([Vector2i(0, rows)])
		print(file, ": rendered ", rows, " rows in ms ", (Time.get_ticks_usec() - started) / 1000.0)
		stream.save_to_wav(out.path_join(file.get_basename() + ".wav"))
	quit()
