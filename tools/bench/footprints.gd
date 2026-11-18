extends SceneTree
## Times the frames of a winter scene without and with footprints (#155): Main starts on a save,
## the snow cover is forced to 1, then the player stands for FRAMES frames, first with clean
## ground, then with a full ring of prints on every loaded chunk (made by a walker on each, as the
## game makes them). Prints the mean and the longest frame of both and how many prints there are.
## Run it with the arguments of `make bench`:
## godot --headless --path . -s tools/bench/footprints.gd -- --save-path=<save> --settings-path=<s>
##   --mute --max-fps=0

const FRAMES := 120
## The frames after the snow is forced that are left out: the ground takes it up in them.
const SKIPPED_FRAMES := 30
## How far a walker goes in one piece of its walk, in tiles (a frame of walking).
const PIECE := 0.1

var main: Node
var frame := 0
var settled_at := -1
var last := 0
var is_snow_started := false
var is_printed := false
var times: Array[float] = []


func _initialize() -> void:
	main = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(main)
	last = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	var ms := (now - last) / 1000.0
	last = now
	if not is_snow_started and main._view.is_settled:
		is_snow_started = true
		main._state.snow_cover.forced = 1.0
	if settled_at < 0 and is_snow_started:
		settled_at = frame
	if settled_at < 0:
		if frame > 3000:
			print("never settled")
			quit()
		return false
	var since_settled := frame - settled_at
	if since_settled < SKIPPED_FRAMES:
		return false
	times.append(ms)
	if times.size() == FRAMES:
		_report("snow with prints" if is_printed else "snow, no prints")
		if is_printed:
			quit()
			return false
		is_printed = true
		times = []
		var started := Time.get_ticks_usec()
		_print_everywhere()
		print("making them took %.0f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
		last = Time.get_ticks_usec()
	return false


## A walker crosses every loaded chunk row by row, so that its ring is full.
func _print_everywhere() -> void:
	var world: World = main._state.world
	var footprints := world.footprints
	var prints := 0
	var loaded := world.loaded_chunk_coords()
	for coords in loaded:
		var origin := Vector2(Chunk.to_world(coords, Vector2i.ZERO))
		var stride := Footprints.Stride.new()
		for row in Chunk.CHUNK_SIZE:
			for piece in int(Chunk.CHUNK_SIZE / PIECE):
				var at := origin + Vector2(piece * PIECE, row + 0.5)
				footprints.walk(world, stride, at, at + Vector2(PIECE, 0.0))
		var ring := footprints.ring_of(coords)
		prints += 0 if ring == null else ring.size
	print("%d prints in %d chunks" % [prints, loaded.size()])


func _report(scenario: String) -> void:
	var sum := 0.0
	var longest := 0.0
	for ms in times:
		sum += ms
		longest = maxf(longest, ms)
	print("%s: mean %.2f ms, longest %.2f ms" % [scenario, sum / times.size(), longest])
