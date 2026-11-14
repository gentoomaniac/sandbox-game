extends SceneTree
## Starts Main headless on a save, waits until the world view has settled and prints the time
## that took, the node count, the entity count, and the frame times of four scenarios, one after
## the other: standing still for 300 frames, passing out (the energy goes to 0) until the player is
## up again, sleeping in the camp's bed, and walking east for WALK_TILES tiles (across chunk
## borders, at the normal pace, through everything). Each prints the mean and the longest frame and
## how many frames went over 33 and over 16.7 ms; the frames over 33 ms are listed with their
## scenario and number. The first frames after the settle are left out. With `--far-trips=<n>` n
## villagers are sent, over and over, to one of 40 tiles 150 to 300 tiles from the player in chunks
## that are not loaded (cold masks, the worker busy), so that the frames can be compared with and
## without them (#68).
## `make bench` runs it on a copy of the fixture save.
## godot --headless --path . -s tools/bench/frames.gd -- --save-path=<save> --settings-path=<s> --mute --max-fps=0
##   [--far-trips=<n>]

enum Scenario { STANDING, PASSING_OUT, SLEEPING, WALKING }

const STAND_FRAMES := 300
const WALK_TILES := 70.0
const SKIPPED_FRAMES := 5
const LONG_MS := 33.0
const SLOW_MS := 16.7
## The time of day the scenarios start at: no late night to pass out in by itself.
const START_HOUR := 10
## How many goals for the far trips (`--far-trips`) to choose from.
const FAR_GOALS := 40
## How often a far walker is sent to a new goal (one search each time).
const FAR_RESEND_SECONDS := 10

var main: Node
var frame := 0
var t0 := 0
var settled_at := -1
var last := 0
var scenario := Scenario.STANDING
var scenario_frame := 0
var times: Array[float] = []
var long_frames: Array[String] = []
var walk_start := Vector2.ZERO
## Whether the fade of the passing out or the sleep has begun: its end ends the scenario.
var has_faded := false
var far_trips := 0
var far_goals: Array[Vector2i] = []
var far_walkers: Array[Npc] = []
var far_sent_at := {}
var far_rng := RandomNumberGenerator.new()


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--far-trips="):
			far_trips = int(argument.trim_prefix("--far-trips="))
	main = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_usec()
	last = t0


func _process(delta: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	var ms := (now - last) / 1000.0
	last = now
	if settled_at < 0 and main._view.is_settled:
		settled_at = frame
		print("settled: frame ", frame, " after ms ", (now - t0) / 1000.0)
		main._state.clock.set_time(START_HOUR, 0)
		_start_far_trips()
	if settled_at < 0:
		if frame > 3000:
			print("never settled")
			quit()
		return false
	var since_settled := frame - settled_at
	if since_settled == SKIPPED_FRAMES:
		_print_counts()
	if since_settled < SKIPPED_FRAMES:
		return false
	scenario_frame += 1
	_resend_far_trips()
	times.append(ms)
	if ms > LONG_MS:
		var name: String = Scenario.keys()[scenario].to_lower()
		long_frames.append("%s frame %d: %.1f ms" % [name, scenario_frame, ms])
	match scenario:
		Scenario.STANDING:
			if scenario_frame == STAND_FRAMES:
				_end_scenario()
				main._state.player.energy = 0.0
		Scenario.PASSING_OUT:
			if _is_fade_over():
				_end_scenario()
				main._try_sleep()
		Scenario.SLEEPING:
			if _is_fade_over():
				_end_scenario()
				main._state.cheats.is_noclip = true
				walk_start = main._state.player.position
		Scenario.WALKING:
			main._state.walk(Vector2.RIGHT, delta)
			if main._state.player.position.x - walk_start.x >= WALK_TILES:
				_end_scenario()
				for line in long_frames:
					print(line)
				quit()
	return false


## Whether a fade has begun and is over: the message after passing out gets its key on the way.
func _is_fade_over() -> bool:
	if main._fade_screen.is_waiting_for_key():
		main._fade_screen.continued.emit()
	has_faded = has_faded or main._is_in_transition
	return has_faded and not main._is_in_transition


func _start_far_trips() -> void:
	if far_trips == 0:
		return
	var state: GameState = main._state
	var missing := far_trips - state.npcs.all().size()
	if missing > 0:
		state.npcs.spawn(missing, state.player.position, state.world)
	# The goals are made now, before the frames are timed: finding grass takes generated chunks.
	var generator := WorldGenerator.new(state.world.world_seed)
	while far_goals.size() < FAR_GOALS:
		var reach := far_rng.randf_range(150.0, 300.0)
		var tile := state.player.tile() + Vector2i(Vector2.from_angle(far_rng.randf() * TAU) * reach)
		var coords := Chunk.world_to_chunk(tile)
		if not World.is_chunk_in_bounds(coords) or state.world.is_chunk_loaded(coords):
			continue
		var chunk := generator.generate_chunk(coords)
		var local := Chunk.local_pos(tile)
		if chunk.terrain_at(local) == Tile.Terrain.GRASS and chunk.object_at(local) == null:
			far_goals.append(tile)
	far_walkers = state.npcs.all().slice(0, far_trips)
	for npc in far_walkers:
		_send_far(npc)


## Sends each far walker again every FAR_RESEND_SECONDS: one search each, at a steady rate. (Walking
## over chunks that are not loaded is not built, so a trip never ends by itself; left to itself it
## would be stuck and search over and over, which is no load anyone will see.)
func _resend_far_trips() -> void:
	var now := Time.get_ticks_usec()
	for npc in far_walkers:
		if now - far_sent_at.get(npc, 0) > FAR_RESEND_SECONDS * 1000000:
			_send_far(npc)


func _send_far(npc: Npc) -> void:
	var state: GameState = main._state
	far_sent_at[npc] = Time.get_ticks_usec()
	state.npcs.cancel_trip(npc)
	state.npcs.walk_to(npc, far_goals[far_rng.randi() % far_goals.size()], state.world)


func _end_scenario() -> void:
	_report(Scenario.keys()[scenario].to_lower(), times)
	scenario = (scenario + 1) as Scenario
	scenario_frame = 0
	has_faded = false
	times = []


func _print_counts() -> void:
	print("nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var sprites := 0
	for c in main._view.entities.get_children():
		if c is Sprite2D:
			sprites += 1
	print("entities children ", main._view.entities.get_child_count(), " pile sprites ", sprites)


func _report(scenario_name: String, times_ms: Array[float]) -> void:
	var sum := 0.0
	var longest := 0.0
	var over_long := 0
	var over_slow := 0
	var sorted := times_ms.duplicate()
	sorted.sort()
	for t in times_ms:
		sum += t
		longest = maxf(longest, t)
		over_long += 1 if t > LONG_MS else 0
		over_slow += 1 if t > SLOW_MS else 0
	print(
		"%s: %d frames, mean %.2f ms, 99th percentile %.1f ms, longest %.1f ms, over 33 ms: %d, over 16.7 ms: %d"
		% [
			scenario_name,
			times_ms.size(),
			sum / times_ms.size(),
			sorted[int(sorted.size() * 0.99)],
			longest,
			over_long,
			over_slow
		]
	)
