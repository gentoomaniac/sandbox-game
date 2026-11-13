extends SceneTree
## Measures what the game's everyday music costs (task 170): each piece of data/music.cfg rendered on
## a worker thread as the game renders it (44.1 kHz stereo, its first section looping) into a fresh
## MusicCache, and then loaded from the cache, with how long each takes from the start to the
## stream being ready, the longest frame the main thread had meanwhile (it must never stall) and
## what the main thread spends taking the finished stream. Headless and silent: nothing is played.
## `make bench-music` runs it after the renderer's benchmark:
## godot --headless --path . -s tools/bench/music_cache.gd

const CACHE_DIR := "user://bench_music_cache"
const RUNS := 3


func _initialize() -> void:
	await process_frame
	var rules := MusicRules.default_rules()
	print(
		(
			"%-14s %-6s %9s %12s %10s %10s"
			% ["piece", "from", "ready ms", "longest frame", "take ms", "file MB"]
		)
	)
	for name in rules.everyday_pieces():
		var piece := MusicPiece.read(MusicPlayer.MUSIC_DIR, name)
		for run in RUNS:
			var cache := MusicCache.new(CACHE_DIR, rules.cache_bytes())
			_remove_cache()
			await _measure(piece, cache, "render")
			await _measure(piece, cache, "cache")
	_remove_cache()
	quit()


## One render of the piece's loop on a worker, polled each frame as the player does.
func _measure(piece: MusicPiece, cache: MusicCache, source: String) -> void:
	var renderer := ModuleRenderer.new(piece.module, MusicPlayer.MIX_RATE, true)
	renderer.rows_per_beat = piece.beat_rows
	renderer.cache = cache
	var started := Time.get_ticks_usec()
	renderer.start([piece.loop_section().part()], true)
	var longest_frame := 0
	var frame_start := started
	while not renderer.is_done():
		await process_frame
		var now := Time.get_ticks_usec()
		longest_frame = maxi(longest_frame, now - frame_start)
		frame_start = now
	var ready := Time.get_ticks_usec()
	renderer.take()
	var taken := Time.get_ticks_usec()
	assert(renderer.was_cached == (source == "cache"))
	print(
		(
			"%-14s %-6s %9.1f %12.1f %10.2f %10.2f"
			% [
				piece.name,
				source,
				(ready - started) / 1000.0,
				longest_frame / 1000.0,
				(taken - ready) / 1000.0,
				cache.size_bytes() / 1e6,
			]
		)
	)


func _remove_cache() -> void:
	if DirAccess.dir_exists_absolute(CACHE_DIR):
		for file_name in DirAccess.get_files_at(CACHE_DIR):
			DirAccess.remove_absolute(CACHE_DIR.path_join(file_name))
