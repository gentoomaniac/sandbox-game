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
		var rows := _rows_once_through(module)
		var started := Time.get_ticks_usec()
		var stream := ModuleRenderer.new(module).render([Vector2i(0, rows)])
		print(file, ": rendered ", rows, " rows in ms ", (Time.get_ticks_usec() - started) / 1000.0)
		stream.save_to_wav(out.path_join(file.get_basename() + ".wav"))
	quit()


## The rows the order list plays once through: each pattern up to its break (D00), or all 64.
func _rows_once_through(module: TrackerModule) -> int:
	var rows := 0
	for pattern in module.order:
		var played := TrackerModule.PATTERN_ROWS
		for row in TrackerModule.PATTERN_ROWS:
			if _breaks(module.patterns[pattern], row):
				played = row + 1
				break
		rows += played
	return rows


static func _breaks(cells: PackedInt32Array, row: int) -> bool:
	for channel in TrackerModule.CHANNELS:
		var at := (row * TrackerModule.CHANNELS + channel) * TrackerModule.CELL_SIZE
		if cells[at + 2] == ModuleRenderer.EFFECT_BREAK:
			return true
	return false
