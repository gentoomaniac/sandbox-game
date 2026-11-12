extends SceneTree
## Starts Main headless on a save, waits until the world view has settled and prints the time
## that took, the node count, the entity count, and the frame times of four scenarios, one after
## the other: standing still for 300 frames, passing out (the energy goes to 0) until the player is
## up again, sleeping in the camp's bed, and walking east for WALK_TILES tiles (across chunk
## borders, at the normal pace, through everything). Each prints the mean and the longest frame and
## how many frames went over 33 and over 16.7 ms; the frames over 33 ms are listed with their
## scenario and number. The first frames after the settle are left out.
## `make bench` runs it on a copy of the fixture save.
## godot --headless --path . -s tools/bench/frames.gd -- --save-path=<save> --settings-path=<s> --mute --max-fps=0

enum Scenario { STANDING, PASSING_OUT, SLEEPING, WALKING }

const STAND_FRAMES := 300
const WALK_TILES := 70.0
const SKIPPED_FRAMES := 5
const LONG_MS := 33.0
const SLOW_MS := 16.7
## The time of day the scenarios start at: no late night to pass out in by itself.
const START_HOUR := 10

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


func _initialize() -> void:
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
	for t in times_ms:
		sum += t
		longest = maxf(longest, t)
		over_long += 1 if t > LONG_MS else 0
		over_slow += 1 if t > SLOW_MS else 0
	print(
		"%s: %d frames, mean %.2f ms, longest %.1f ms, over 33 ms: %d, over 16.7 ms: %d"
		% [scenario_name, times_ms.size(), sum / times_ms.size(), longest, over_long, over_slow]
	)
