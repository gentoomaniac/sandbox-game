extends SceneTree
## Measures the prototype music renderer of task 169 (game/audio/module_renderer.gd) on the test
## piece, headless and muted. First on its own: how long a render takes (the 8-bar loop and a
## minute of the piece, at 22.05 and 44.1 kHz, mono and stereo) and how much memory its stream
## takes. Then in the game, on a save: the frame times standing with no render, with renders of a
## minute running one after the other on a worker thread, and with a timed save in the middle of
## them, each with the mean and longest frame and how many frames went over 33 and over 16.7 ms
## (listed with what was done the frame before); and what the main thread spends on each finished
## render: taking the stream the worker made and handing it to a MusicCrossfade, which plays it or
## crossfades to it on the next beat (muted), and the crossfade's own work in a frame.
## `make bench-music` runs it on a copy of the bench save:
## godot --headless --path . -s tools/bench/music.gd --
##     --save-path=<save> --settings-path=<settings> --mute

enum Scenario { STANDING, RENDERING, SAVING, DONE }

const MODULE := "res://assets/music/test_reel.mod"
const LOOP_ROWS := 128
## A minute of the piece (60.0 s at its 141.5 ms a row): the order list goes round, loop and fill.
const MINUTE_ROWS := 424
const RUNS := 3
const SCENARIO_FRAMES := 300
const SKIPPED_FRAMES := 5
const LONG_MS := 33.0
const SLOW_MS := 16.7
## The render that runs in the game's scenarios: the heaviest of the table.
const GAME_RATE := 44100
const GAME_STEREO := true

var main: Node
var module: TrackerModule
var renderer: ModuleRenderer
var crossfade: MusicCrossfade
var render_started := 0
var render_ms: Array[float] = []
## Per render taken in the game, the main thread's microseconds to take it and to hand it to the
## crossfade.
var handoff_usec: Array[Vector2] = []
## The longest the crossfade worked in a frame (starting a stream on the beat, fading), in
## microseconds, and how late after their beats the crossfades began, in ms.
var longest_crossfade_usec := 0
var lateness_ms: Array[float] = []
var long_frames: Array[String] = []
## What `_keep_rendering` did in the frame before, which the next frame's time includes.
var last_frame_did := ""
var frame := 0
var settled_at := -1
var last := 0
var scenario := Scenario.STANDING
var scenario_frame := 0
var times: Array[float] = []
var save_started := false
## The frame of the saving scenario the save ended in, and whether it was written.
var save_ended_frame := -1
var save_succeeded := false


func _initialize() -> void:
	module = TrackerModule.from_bytes(FileAccess.get_file_as_bytes(MODULE))
	_print_render_times()
	main = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(main)
	crossfade = MusicCrossfade.new()
	# Its frame work is timed here, in _process.
	crossfade.set_process(false)
	root.add_child(crossfade)
	renderer = ModuleRenderer.new(module, GAME_RATE, GAME_STEREO)
	last = Time.get_ticks_usec()


func _print_render_times() -> void:
	print("cpu: ", OS.get_processor_name(), ", ", OS.get_processor_count(), " threads")
	var started := Time.get_ticks_usec()
	TrackerModule.from_bytes(FileAccess.get_file_as_bytes(MODULE))
	print("reading the module: %.2f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	for rows in [LOOP_ROWS, MINUTE_ROWS]:
		for rate in [22050, 44100]:
			for stereo in [false, true]:
				var best := INF
				var stream: AudioStreamWAV
				for run in RUNS:
					started = Time.get_ticks_usec()
					stream = ModuleRenderer.new(module, rate, stereo).render([Vector2i(0, rows)])
					best = minf(best, (Time.get_ticks_usec() - started) / 1000.0)
				var seconds := stream.get_length()
				print(
					(
						"render %4.1f s at %d Hz %s: %7.1f ms (best of %d), %.0fx real time, %.2f MB, %.2f MB/min"
						% [
							seconds,
							rate,
							"stereo" if stereo else "mono  ",
							best,
							RUNS,
							seconds * 1000.0 / best,
							stream.data.size() / 1048576.0,
							stream.data.size() / 1048576.0 * 60.0 / seconds,
						]
					)
				)


func _process(_delta: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	var ms := (now - last) / 1000.0
	last = now
	if settled_at < 0:
		if main._view.is_settled:
			settled_at = frame
		elif frame > 3000:
			print("never settled")
			quit()
		return false
	if frame - settled_at < SKIPPED_FRAMES:
		return false
	scenario_frame += 1
	times.append(ms)
	if ms > SLOW_MS:
		var name: String = Scenario.keys()[scenario].to_lower()
		long_frames.append("%s frame %d: %.1f ms, %s" % [name, scenario_frame, ms, last_frame_did])
	last_frame_did = _keep_rendering()
	match scenario:
		Scenario.STANDING, Scenario.RENDERING:
			if scenario_frame == SCENARIO_FRAMES:
				_end_scenario()
		Scenario.SAVING:
			if scenario_frame == 10:
				save_started = main._saves.save_in_background(main._state, main._options.save_path)
				last_frame_did += " the save started"
			if save_started and save_ended_frame < 0 and not main._saves.is_running():
				save_ended_frame = scenario_frame
				save_succeeded = main._saves.last_succeeded
			if scenario_frame == SCENARIO_FRAMES:
				print(
					(
						"the save: started %s, ended in frame %d (started in 10), written %s"
						% [save_started, save_ended_frame, save_succeeded]
					)
				)
				_end_scenario()
		Scenario.DONE:
			_report_renders()
			quit()
	return false


## While rendering or saving, a render runs on a worker all the time: a finished one is taken and
## handed to the crossfade (played at first, then crossfaded to on the next beat over a beat), and
## the next started. Also runs the crossfade's frame. Returns what it did, for the list of long
## frames.
func _keep_rendering() -> String:
	var did := ""
	var was_waiting := crossfade._next != null
	var started := Time.get_ticks_usec()
	crossfade._process(0.0)
	longest_crossfade_usec = maxi(longest_crossfade_usec, Time.get_ticks_usec() - started)
	if was_waiting and crossfade._next == null:
		lateness_ms.append(crossfade.lateness * 1000.0)
		did = "a crossfade began"
	if scenario == Scenario.STANDING:
		return did
	if renderer.is_done():
		started = Time.get_ticks_usec()
		var stream := renderer.take()
		var taken := Time.get_ticks_usec()
		if crossfade._players[crossfade._current].playing:
			crossfade.crossfade(stream, renderer.beat_seconds, renderer.beat_seconds)
		else:
			crossfade.play(stream, renderer.beat_seconds)
		handoff_usec.append(Vector2(taken - started, Time.get_ticks_usec() - taken))
		render_ms.append((started - render_started) / 1000.0)
		did += " a render taken and handed over"
	if not renderer.is_rendering():
		render_started = Time.get_ticks_usec()
		renderer.start([Vector2i(0, MINUTE_ROWS)])
		did += " a render started"
	return did


func _end_scenario() -> void:
	var sum := 0.0
	var longest := 0.0
	var over_long := 0
	var over_slow := 0
	for t in times:
		sum += t
		longest = maxf(longest, t)
		over_long += 1 if t > LONG_MS else 0
		over_slow += 1 if t > SLOW_MS else 0
	print(
		(
			"%s: %d frames, mean %.2f ms, longest %.1f ms, over 33 ms: %d, over 16.7 ms: %d"
			% [
				Scenario.keys()[scenario].to_lower(),
				times.size(),
				sum / times.size(),
				longest,
				over_long,
				over_slow,
			]
		)
	)
	scenario = (scenario + 1) as Scenario
	scenario_frame = 0
	times = []


func _report_renders() -> void:
	var longest := Vector2.ZERO
	for usec in handoff_usec:
		longest = longest.max(usec)
	print(
		(
			"in the game: %d renders of a minute at %d Hz stereo on a worker, ms: %s"
			% [render_ms.size(), GAME_RATE, render_ms]
		)
	)
	print(
		(
			(
				"main thread per render, longest ms: take %.3f, hand to the crossfade %.3f;"
				+ " the crossfade's frame work, longest %.3f ms"
			)
			% [longest.x / 1000.0, longest.y / 1000.0, longest_crossfade_usec / 1000.0]
		)
	)
	print("crossfades began after their beats by ms: ", lateness_ms)
	for line in long_frames:
		print(line)
	if renderer.is_rendering():
		renderer.take()
