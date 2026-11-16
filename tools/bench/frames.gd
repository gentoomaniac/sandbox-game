extends SceneTree
## Starts Main headless on a save, waits until the world view has settled and prints the time
## that took, the node count, the entity count, and the frame times of four scenarios, one after
## the other: standing still for 300 frames, passing out (the energy goes to 0) until the player is
## up again, sleeping in the camp's bed, and walking east for WALK_TILES tiles (across chunk
## borders, at the normal pace, through everything). Each prints the mean and the longest frame and
## how many frames went over 33 and over 16.7 ms; the frames over 33 ms are listed with their
## scenario and number. The first frames after the settle are left out. With `--far-trips=<n>` n
## villagers are sent, one trip after the other, to one of FAR_GOALS tiles 150 to 300 tiles from the
## player in chunks that are not loaded (cold masks, the worker busy), and walk there: goals are
## chosen that a way leads to from the player. A trip lasts 100 to 200 s at the villagers' pace, so
## `--far-speed=<factor>` (default 20) multiplies `walk_speed`: trips end within the run, and each
## walker enters tiles (mask lookups, wear) that much faster. The end prints the trips completed
## and blocked and the searches a second, so that the frames can be compared with and without them
## (#68).
## `--snow=<cover>` forces the snow cover (0 to 1) on a summer day after the settle and prints how
## long one check of the flowers in bloom round the view takes, which the wildlife makes every
## second (#91), and ends the run. With 0.4 no tile counts as snowed, so every flower still blooms
## and is asked about.
## `make bench` runs it on a copy of the fixture save.
## godot --headless --path . -s tools/bench/frames.gd -- --save-path=<save> --settings-path=<s>
##   --mute --max-fps=0
##   [--far-trips=<n> [--far-speed=<factor>]] [--snow=<cover>]

enum Scenario { STANDING, PASSING_OUT, SLEEPING, WALKING }

const STAND_FRAMES := 300
const WALK_TILES := 70.0
const SKIPPED_FRAMES := 5
const LONG_MS := 33.0
const SLOW_MS := 16.7
## The time of day the scenarios start at: no late night to pass out in by itself.
const START_HOUR := 10
## The day `--snow` sets: in the summer, when the flowers bloom.
const SNOW_BENCH_DAY := 45
## How many checks of the flowers are timed for their mean.
const FLOWER_CHECKS := 10
## How many goals for the far trips (`--far-trips`) to choose from.
const FAR_GOALS := 24
## How long a far walker whose trip is blocked waits before it is sent to another goal.
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
var snow_cover := -1.0
var is_snow_started := false
var far_speed := 20.0
var far_goals: Array[Vector2i] = []
var far_walkers: Array[Npc] = []
var far_sent_at := {}
var far_rng := RandomNumberGenerator.new()
var far_started_at := 0
var far_arrived := 0
var far_blocked: Array[int] = [0, 0]
## What each walker's current trip had made of searches when last seen, to count them when it ends.
var far_trip_searches: Dictionary[Npc, int] = {}
var far_trip_of: Dictionary[Npc, NpcTrip] = {}
var far_searches := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--far-trips="):
			far_trips = int(argument.trim_prefix("--far-trips="))
		elif argument.begins_with("--snow="):
			snow_cover = float(argument.trim_prefix("--snow="))
		elif argument.begins_with("--far-speed="):
			far_speed = float(argument.trim_prefix("--far-speed="))
	main = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_usec()
	last = t0


func _process(delta: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	var ms := (now - last) / 1000.0
	last = now
	if snow_cover >= 0.0 and not is_snow_started and main._view.is_settled:
		_start_snow()
	if settled_at < 0 and main._view.is_settled and main._view._refresh_queue.is_empty():
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
				main._blackout.try_sleep()
		Scenario.SLEEPING:
			if _is_fade_over():
				_end_scenario()
				main._state.cheats.is_noclip = true
				walk_start = main._state.player.position
		Scenario.WALKING:
			PlayerTravel.walk(main._state, Vector2.RIGHT, delta)
			if main._state.player.position.x - walk_start.x >= WALK_TILES:
				_end_scenario()
				for line in long_frames:
					print(line)
				_print_far_trips()
				quit()
	return false


## Whether a fade has begun and is over: the message after passing out gets its key on the way.
func _is_fade_over() -> bool:
	if main._fade_screen.is_waiting_for_key():
		main._fade_screen.continued.emit()
	has_faded = has_faded or main._blackout.is_in_transition
	return has_faded and not main._blackout.is_in_transition


## Puts the summer day and the snow cover on the settled view; the settle is over when it has drawn
## the day's flowers (its `_refresh_queue`).
func _start_snow() -> void:
	is_snow_started = true
	main._state.snow_cover.forced = snow_cover
	main._state.clock.day = SNOW_BENCH_DAY
	main._show_clock()


func _start_far_trips() -> void:
	if far_trips == 0:
		return
	var state: GameState = main._state
	var missing := far_trips - state.npcs.all().size()
	if missing > 0:
		state.npcs.spawn(missing, state.player.position, state.world)
	# The goals are made now, before the frames are timed: finding grass takes generated chunks, and
	# the way to each is searched here (a goal on an island is no goal).
	var generator := WorldGenerator.new(state.world.world_seed)
	var masks := TravelMasks.for_world(state.world, state.npcs.rules)
	while far_goals.size() < FAR_GOALS:
		var reach := far_rng.randf_range(150.0, 300.0)
		var tile := (
			state.player.tile() + Vector2i(Vector2.from_angle(far_rng.randf() * TAU) * reach)
		)
		var coords := Chunk.world_to_chunk(tile)
		if not World.is_chunk_in_bounds(coords) or state.world.is_chunk_loaded(coords):
			continue
		var chunk := generator.generate_chunk(coords)
		var local := Chunk.local_pos(tile)
		if (
			chunk.terrain_at(local) == Tile.Terrain.GRASS
			and chunk.object_at(local) == null
			and _is_reachable(state, masks, state.player.tile(), tile)
		):
			far_goals.append(tile)
	state.npcs.rules._values["behaviour"]["walk_speed"] *= far_speed
	state.npcs.trip_arrived.connect(func(_npc: Npc) -> void: far_arrived += 1)
	state.npcs.trip_blocked.connect(
		func(_npc: Npc, reason: NpcTrip.Block) -> void: far_blocked[reason] += 1
	)
	far_walkers = state.npcs.all().slice(0, far_trips)
	far_started_at = Time.get_ticks_usec()
	for npc in far_walkers:
		_send_far(npc)


## Whether a way leads from `start` to `goal`: searched over the masks as the villagers do, leg
## after leg, on this thread.
func _is_reachable(state: GameState, masks: TravelMasks, start: Vector2i, goal: Vector2i) -> bool:
	var rules: NpcRules = state.npcs.rules
	var view := TravelView.new(
		TravelSnapshot.of(state.world, 0), rules, state.world.clock.total_minutes()
	)
	for _leg in int(rules.travel("max_legs")) + 1:
		var search := PathSearch.new(
			start,
			goal,
			view.is_free,
			view.cost_of,
			int(rules.travel("max_nodes")),
			rules.travel("heuristic_weight"),
			view.is_known
		)
		while not search.is_over():
			if search.step(1 << 30) == PathSearch.State.WAITING:
				while not view.provide(masks):
					masks.update(true)
		if search.state == PathSearch.State.FOUND:
			return true
		if search.state != PathSearch.State.LEG:
			return false
		start = search.path.back()
	return false


## Sends a far walker whose trip is over to a new goal, and one whose trip has been blocked for
## FAR_RESEND_SECONDS. Counts the searches the trips make: a trip's own count, when it ends.
func _resend_far_trips() -> void:
	var now := Time.get_ticks_usec()
	for npc in far_walkers:
		var trip := npc.trip
		if far_trip_of.get(npc) != trip:
			far_searches += far_trip_searches.get(npc, 0)
			far_trip_searches[npc] = 0
			far_trip_of[npc] = trip
		if trip != null:
			far_trip_searches[npc] = trip.searches
		if trip == null:
			_send_far(npc)
		elif (
			trip.state == NpcTrip.State.BLOCKED
			and now - far_sent_at.get(npc, 0) > FAR_RESEND_SECONDS * 1000000
		):
			_send_far(npc)


func _send_far(npc: Npc) -> void:
	var state: GameState = main._state
	far_sent_at[npc] = Time.get_ticks_usec()
	state.npcs.cancel_trip(npc)
	state.npcs.walk_to(npc, far_goals[far_rng.randi() % far_goals.size()], state.world)


func _print_far_trips() -> void:
	if far_trips == 0:
		return
	for npc in far_walkers:
		far_searches += far_trip_searches.get(npc, 0)
	var seconds := (Time.get_ticks_usec() - far_started_at) / 1000000.0
	print(
		(
			(
				"far trips: %d walkers at %.0fx the pace, %d trips completed, "
				+ "%d blocked (%d no way, %d stuck), "
				+ "%d searches in %.1f s (%.2f a second)"
			)
			% [
				far_trips,
				far_speed,
				far_arrived,
				far_blocked[0] + far_blocked[1],
				far_blocked[NpcTrip.Block.NO_WAY],
				far_blocked[NpcTrip.Block.STUCK],
				far_searches,
				seconds,
				far_searches / seconds
			]
		)
	)


func _end_scenario() -> void:
	_report(Scenario.keys()[scenario].to_lower(), times)
	scenario = (scenario + 1) as Scenario
	scenario_frame = 0
	has_faded = false
	times = []


## The time of the wildlife's check of the flowers in bloom round the view, which it makes every
## second (see WildlifeView `_match_counts`).
func _print_flower_check() -> void:
	var wildlife: WildlifeView = main._wildlife
	var flowers := wildlife._flowers_near_view()
	var start := Time.get_ticks_usec()
	for _check in FLOWER_CHECKS:
		wildlife._flowers_near_view()
	var check_ms := (Time.get_ticks_usec() - start) / 1000.0 / FLOWER_CHECKS
	print(
		(
			"snow cover %s: %d flowers in bloom round the view, a check takes %.2f ms"
			% [snow_cover, flowers.size(), check_ms]
		)
	)


func _print_counts() -> void:
	if snow_cover >= 0.0:
		_print_flower_check()
		quit()
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
		(
			(
				"%s: %d frames, mean %.2f ms, 99th percentile %.1f ms, longest %.1f ms, "
				+ "over 33 ms: %d, over 16.7 ms: %d"
			)
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
	)
