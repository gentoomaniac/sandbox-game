extends SceneTree
## Starts Main headless on a save, waits until the world view has settled and prints the time
## that took, the node count, the entity count, and the frame times of two scenarios: standing
## still for 300 frames, then sleeping in the camp's bed until the day is back, then walking east for WALK_TILES tiles (across chunk borders, at the
## normal pace, through everything). Each prints the mean and the longest frame and how many
## frames went over 33 and over 16.7 ms; the frames over 33 ms are listed with their number, and
## a note if the player was passing out then. The first frames after the settle are left out.
## `make bench` runs it on a copy of the fixture save.
## godot --headless --path . -s tools/bench/frames.gd -- --save-path=<save> --settings-path=<s> --mute

const STAND_FRAMES := 300
const WALK_TILES := 70.0
const SKIPPED_FRAMES := 5
const LONG_MS := 33.0
const SLOW_MS := 16.7

var main: Node
var frame := 0
var t0 := 0
var settled_at := -1
var last := 0
var standing: Array[float] = []
var sleeping: Array[float] = []
var walking: Array[float] = []
var sleep_started := false
var sleeping_done := false
var long_frames: Array[String] = []
var walk_start := Vector2.ZERO


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
	if settled_at < 0:
		if frame > 3000:
			print("never settled")
			quit()
		return false
	var since_settled := frame - settled_at
	if since_settled == SKIPPED_FRAMES:
		_print_counts()
	if ms > LONG_MS and since_settled >= SKIPPED_FRAMES:
		var scenario := _scenario(since_settled)
		var cause := " (passing out or a fade)" if main._is_in_transition else ""
		long_frames.append("%s frame %d: %.1f ms%s" % [scenario, since_settled, ms, cause])
	if since_settled <= STAND_FRAMES:
		standing.append(ms)
		if since_settled == STAND_FRAMES:
			_report("standing", standing)
		return false
	if not sleeping_done:
		_sleep(ms)
		return false
	walking.append(ms)
	main._state.walk(Vector2.RIGHT, delta)
	if main._state.player.position.x - walk_start.x >= WALK_TILES:
		_report("walking", walking)
		for line in long_frames:
			print(line)
		quit()
	return false


func _scenario(since_settled: int) -> String:
	if since_settled <= STAND_FRAMES:
		return "standing"
	return "walking" if sleeping_done else "sleeping"


## Sleeps in the bed once nothing else fades (the pass-out's message gets its key), times the
## frames until the fade is over, then readies the walk.
func _sleep(ms: float) -> void:
	if not sleep_started:
		if main._fade_screen.is_waiting_for_key():
			main._fade_screen.continued.emit()
		if main._is_in_transition:
			return
		sleep_started = true
		main._try_sleep()
		return
	sleeping.append(ms)
	if not main._is_in_transition:
		sleeping_done = true
		_report("sleeping", sleeping)
		main._state.cheats.is_noclip = true
		walk_start = main._state.player.position


func _print_counts() -> void:
	print("nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var sprites := 0
	for c in main._view.entities.get_children():
		if c is Sprite2D:
			sprites += 1
	print("entities children ", main._view.entities.get_child_count(), " pile sprites ", sprites)


func _report(scenario: String, all_times: Array[float]) -> void:
	var times := all_times.slice(SKIPPED_FRAMES) if scenario == "standing" else all_times
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
		"%s: %d frames, mean %.2f ms, longest %.1f ms, over 33 ms: %d, over 16.7 ms: %d"
		% [scenario, times.size(), sum / times.size(), longest, over_long, over_slow]
	)
