extends SceneTree
## What villagers sent far away cost (#68 step 6, design/villagers/travel.md and
## design/tech/pathfinding.md).
## `send=<n>` villagers of a save (default all) walk to a tile REACH tiles away that a way leads to,
## over loaded ground and unloaded, while `Npcs.update` runs frame after frame at 60 frames per
## real second (paced, since the workers work in real time). Two scenarios, each run first with cold
## masks (made as the searches ask) and then with warm ones (the same trips again, over what the
## first run left):
## - once: all leave in the same frame; `once=<seconds>` (default 90).
## - day: each leaves at a random moment of the first half, then goes to and fro between home and
##   goal, resting up to REST_SECONDS at each end; `day=<seconds>` (default 300).
## - skip: all leave in the same frame and walk SKIP_WALK_SECONDS; then a time skip of
##   `skip=<minutes>` (default 240) takes them on, all of it waiting (`Npcs.catch_up`): how long
##   that takes, and how long the masks it needs make it wait.
## 0 leaves a scenario out. Before them, a run of frames with no trips is the baseline.
##
## A run prints what the main thread spends in a frame, in milliseconds (mean / 99th percentile /
## longest), split as the game calls it: walking (`Npcs.update`, which also begins the search of a
## walker that is stuck; it does the others' strolling too), the pathfinder's `tick` (reaping,
## parked searches, starting tasks), `TravelMasks.update`, and sending (`walk_to`: snapshot,
## prefetch, queueing). Then the trips sent, arrived and blocked; the wait for the first leg (the
## longest is the last departure's delay); the searches a second and the tiles they looked at,
## and from them how busy a worker was (at SECONDS_A_TILE); the masks kept; memory.
## The pieces come from Npcs' `_travel`, which this reaches into: `update` is called with
## `may_search = false`, which leaves out its `tick`, and the `tick` is timed on its own.
## `make bench` writes the save (build/bench/fixture.save); this needs no Main. Run it with
## `taskset`.
## godot --headless --path . -s tools/bench/paths.gd -- <save file> [<key>=<number> ...]
## The keys after the save are `send`, `once`, `day` and `skip`, `speed=<factor>` to multiply
## `walk_speed` (trips end that much sooner, and the next is searched sooner: a stress), or numbers
## of [travel] (data/npcs.cfg) to try instead, such as `search_tasks=2 snapshot_seconds=5`.

const FRAME_SECONDS := 1.0 / 60.0
const FRAME_USEC := 16667
const SLOW_FRAME_MS := 16.7
const REACH := Vector2i(100, 300)
const GOAL_TRIES := 60
const BASELINE_SECONDS := 30.0
const SKIP_WALK_SECONDS := 20.0
const PROBE_TILES := 512
const PROBE_LOOKUPS := 4000
const HOUR := 10
## The chunks loaded round the player, as many as in the save the game plays (13 x 13).
const CHUNK_RADIUS := 6
const REST_SECONDS := 20.0
## A blocked trip is left after this many seconds, and the villager goes the other way.
const BLOCKED_GIVE_UP_SECONDS := 30.0
## What a tile looked at costs a worker, in seconds (far_search.gd: 9.2 to 9.4 us over warm masks).
const SECONDS_A_TILE := 9.3e-6
## The masks and raw chunks the goals are picked with, so many that none is made twice.
const GOAL_MASKS_KEPT := 8192
const GOAL_CHUNKS_KEPT := 128

var _state: GameState
var _rng := RandomNumberGenerator.new()
var _send_count := 1000000
var _once_seconds := 90.0
var _day_seconds := 300.0
var _skip_minutes := 240
var _villagers: Array[Npc] = []
var _homes: Dictionary[Npc, Vector2] = {}
var _goals: Dictionary[Npc, Vector2i] = {}

## Of the run: the clock of its game time; what is going on with the trips.
var _now := 0.0
var _is_day := false
var _next_send_at: Dictionary[Npc, float] = {}
var _sent_at: Dictionary[Npc, float] = {}
var _is_going_out: Dictionary[Npc, bool] = {}
var _searching_since: Dictionary[Npc, float] = {}
var _first_leg_waits: Array[float] = []
var _sent := 0
var _arrived := 0
var _blocked_by_reason := {}
## For each trip, what it has made of searches and tiles looked at so far, to add up the difference.
var _trip_searches: Dictionary[NpcTrip, int] = {}
var _trip_nodes: Dictionary[NpcTrip, int] = {}
var _searches := 0
var _nodes := 0
var _snapshots := 0
var _memory_before := 0
var _memory_peak := 0
var _last_snapshot: TravelSnapshot
## Per frame, in milliseconds.
var _walk_ms: Array[float] = []
var _pathfinder_ms: Array[float] = []
var _masks_ms: Array[float] = []
var _sending_ms: Array[float] = []
var _total_ms: Array[float] = []
var _probe_ms: Array[float] = []
var _probe_table: Dictionary[Vector2i, int] = {}


func _init() -> void:
	_state = SaveFile.read(OS.get_cmdline_user_args()[0])
	_state.clock.set_time(HOUR, 0)
	_load_chunks()
	for index in PROBE_TILES:
		_probe_table[Vector2i(index, 0)] = index
	var npcs := _state.npcs
	npcs.rules = _rules_with_arguments()
	npcs.trip_arrived.connect(_on_arrived)
	npcs.trip_blocked.connect(_on_blocked)
	_villagers = npcs.all().slice(0, _send_count)
	for npc in _villagers:
		_homes[npc] = npc.position
	print("villagers ", _villagers.size(), " of ", npcs.all().size())
	_pick_goals()
	_run_baseline()
	if _once_seconds > 0.0:
		_run_scenario("once", false, _once_seconds)
	if _day_seconds > 0.0:
		_run_scenario("day", true, _day_seconds)
	if _skip_minutes > 0:
		_run_skip_scenario()
	quit()


## The rules of data/npcs.cfg with the numbers of the command line.
func _rules_with_arguments() -> NpcRules:
	var values := DataFile.read_sections(NpcRules.DEFAULT_PATH)
	for argument in OS.get_cmdline_user_args().slice(1):
		var pair := argument.split("=")
		match pair[0]:
			"send":
				_send_count = int(pair[1])
			"once":
				_once_seconds = float(pair[1])
			"day":
				_day_seconds = float(pair[1])
			"skip":
				_skip_minutes = int(pair[1])
			"speed":
				values["behaviour"]["walk_speed"] *= float(pair[1])
			_:
				values["travel"][pair[0]] = float(pair[1])
				print("[travel] ", argument)
	return NpcRules.new(values)


## The world of a save has no chunks until the game streams them in: load those round the player.
func _load_chunks() -> void:
	var generator := WorldGenerator.new(_state.world.world_seed)
	var centre := Chunk.world_to_chunk(_state.player.tile())
	for y in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for x in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			var coords := centre + Vector2i(x, y)
			if World.is_chunk_in_bounds(coords) and not _state.world.is_chunk_loaded(coords):
				_state.world.add_chunk(generator.generate_chunk(coords))


## A goal for each villager: a tile a villager can stand on, REACH tiles away, that a way leads
## to (a goal on an island is no goal). Not timed. It uses masks of its own, and lets go of them, so
## that the masks of the runs are not warm by it.
func _pick_goals() -> void:
	_rng.seed = 1
	var rules := _state.npcs.rules
	var masks := TravelMasks.new(_state.world, GOAL_MASKS_KEPT, GOAL_CHUNKS_KEPT)
	var view := TravelView.new(
		TravelSnapshot.of(_state.world, 0), rules, _state.world.clock.total_minutes()
	)
	for npc in _villagers:
		for _try in GOAL_TRIES:
			var distance := _rng.randf_range(REACH.x, REACH.y)
			var tile := (
				npc.tile() + Vector2i((Vector2.from_angle(_rng.randf() * TAU) * distance).round())
			)
			if _is_free(tile, view, masks) and _is_reachable(npc.tile(), tile, view, masks):
				_goals[npc] = tile
				break
		if not _goals.has(npc):
			push_warning("%s has no goal" % npc.name)
			_goals[npc] = npc.tile()


## Whether a villager can stand on `tile` (false out of the world).
func _is_free(tile: Vector2i, view: TravelView, masks: TravelMasks) -> bool:
	if not World.is_chunk_in_bounds(Chunk.world_to_chunk(tile)):
		return false
	view.is_known(tile)
	while not view.provide(masks):
		masks.update(true)
	return view.is_free(tile)


## Whether a way leads from `start` to `goal`: searched over the masks as the villagers do, leg
## after leg, on this thread.
func _is_reachable(start: Vector2i, goal: Vector2i, view: TravelView, masks: TravelMasks) -> bool:
	var rules := _state.npcs.rules
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


## What the frames cost with nobody on a trip: the villagers that stand and stroll, all of them.
func _run_baseline() -> void:
	_is_day = false
	_reset_run()
	for npc in _villagers:
		_next_send_at[npc] = -1.0
	_run_frames(BASELINE_SECONDS)
	print("\n[no trips]")
	print("  Npcs.update's parts together  ", _stats(_total_ms))
	print("  probe (the same work)         ", _stats(_probe_ms))


## The scenario with cold masks, then with warm ones.
func _run_scenario(title: String, is_day: bool, seconds: float) -> void:
	_is_day = is_day
	# The same rules again: the masks and the snapshot are made again, from nothing.
	_state.npcs.rules = _state.npcs.rules
	for temperature in ["cold", "warm"]:
		_reset_run()
		_run_frames(seconds)
		print("\n[%s, %s masks, %d villagers]" % [title, temperature, _villagers.size()])
		_print_run(seconds)
		_end_run()


## All leave at once, walk a while, and the time skip takes them on.
func _run_skip_scenario() -> void:
	_is_day = false
	_state.npcs.rules = _state.npcs.rules
	for temperature in ["cold", "warm"]:
		_reset_run()
		_run_frames(SKIP_WALK_SECONDS)
		var started := Time.get_ticks_usec()
		_state.npcs.catch_up(_state.world, 1, _skip_minutes)
		var travel: NpcTravel = _state.npcs._travel
		print(
			(
				(
					"\n[skip of %d minutes, %s masks, %d villagers]\nthe skip took %.2f s; %d of %d arrived "
					+ "in it; masks kept %d"
				)
				% [
					_skip_minutes,
					temperature,
					_villagers.size(),
					(Time.get_ticks_usec() - started) / 1e6,
					_arrived,
					_sent,
					travel._masks.mask_coords().size()
				]
			)
		)
		_print_footprint()
		_end_run()


## Starts a run: the villagers at home, with the departures planned.
func _reset_run() -> void:
	_rng.seed = 2
	_now = 0.0
	_sent = 0
	_arrived = 0
	_searches = 0
	_nodes = 0
	_snapshots = 0
	_blocked_by_reason.clear()
	_first_leg_waits.clear()
	for list in [_walk_ms, _pathfinder_ms, _masks_ms, _sending_ms, _total_ms, _probe_ms]:
		list.clear()
	for npc in _villagers:
		npc.position = _homes[npc]
		_is_going_out[npc] = true
		_next_send_at[npc] = _rng.randf_range(0.0, _day_seconds / 2.0) if _is_day else 0.0
	_memory_before = OS.get_static_memory_usage()
	_memory_peak = _memory_before


## Ends the trips that are on and waits until the worker has done with their searches.
func _end_run() -> void:
	var travel: NpcTravel = _state.npcs._travel
	for npc in _villagers:
		_state.npcs.cancel_trip(npc)
	_sent_at.clear()
	_searching_since.clear()
	_trip_searches.clear()
	_trip_nodes.clear()
	while travel._pathfinder.running() > 0 or travel._pathfinder.waiting() > 0:
		travel.tick()
		OS.delay_usec(1000)


## Runs `seconds` of frames at 60 a second, timing the parts of what the main thread does.
func _run_frames(seconds: float) -> void:
	var travel: NpcTravel = _state.npcs._travel
	var frames := roundi(seconds / FRAME_SECONDS)
	var next_frame_at := Time.get_ticks_usec()
	for _frame in frames:
		_now += FRAME_SECONDS
		var sending_usec := _send_villagers()
		var masks_started := Time.get_ticks_usec()
		if travel._masks != null:
			travel._masks.update()
		var pathfinder_started := Time.get_ticks_usec()
		travel._pathfinder.tick()
		var walk_started := Time.get_ticks_usec()
		_state.npcs.update(
			FRAME_SECONDS, _state.world, _state.player.position, _state.clock, false, false
		)
		var ended := Time.get_ticks_usec()
		_masks_ms.append((pathfinder_started - masks_started) / 1000.0)
		_pathfinder_ms.append((walk_started - pathfinder_started) / 1000.0)
		_walk_ms.append((ended - walk_started) / 1000.0)
		_sending_ms.append(sending_usec / 1000.0)
		_total_ms.append((ended - masks_started + sending_usec) / 1000.0)
		_probe_ms.append(_time_probe())
		_memory_peak = maxi(_memory_peak, OS.get_static_memory_usage())
		_note_trips()
		next_frame_at += FRAME_USEC
		var wait := next_frame_at - Time.get_ticks_usec()
		if wait > 0:
			OS.delay_usec(wait)
		else:
			next_frame_at = Time.get_ticks_usec()


## How long a fixed piece of work takes on this thread, in milliseconds: lookups in a table of
## tiles, as the walkers and the masks do. It does not change with what the game does, so if it
## takes longer while the workers search, they are in the main thread's way (the memory, the cache).
func _time_probe() -> float:
	var started := Time.get_ticks_usec()
	var sum := 0
	for index in PROBE_LOOKUPS:
		sum += _probe_table[Vector2i(index % PROBE_TILES, 0)]
	return (Time.get_ticks_usec() - started) / 1000.0


## Sends the villagers who are due (once: all, in the first frame; day: to and fro, with their
## rests). Returns the microseconds that took.
func _send_villagers() -> int:
	var started := Time.get_ticks_usec()
	for npc in _villagers:
		var trip := npc.trip
		if trip != null and trip.state == NpcTrip.State.BLOCKED:
			if _is_day and _now - _sent_at[npc] > BLOCKED_GIVE_UP_SECONDS:
				_state.npcs.cancel_trip(npc)
				_next_send_at[npc] = _now
			continue
		if trip != null or _now < _next_send_at[npc] or _next_send_at[npc] < 0.0:
			continue
		var goal := _goals[npc] if _is_going_out[npc] else _tile_of(_homes[npc])
		if goal == npc.tile():
			_next_send_at[npc] = -1.0
			continue
		_is_going_out[npc] = not _is_going_out[npc]
		_sent += 1
		_sent_at[npc] = _now
		_searching_since[npc] = _now
		_state.npcs.walk_to(npc, goal, _state.world)
	return Time.get_ticks_usec() - started


func _tile_of(feet: Vector2) -> Vector2i:
	return Vector2i(feet.floor())


## Notes the first legs that are done, the searches and tiles of the trips, the snapshots.
func _note_trips() -> void:
	for npc in _villagers:
		var trip := npc.trip
		if trip == null:
			continue
		if _searching_since.has(npc) and trip.state != NpcTrip.State.SEARCHING:
			_first_leg_waits.append(_now - _searching_since[npc])
			_searching_since.erase(npc)
		_searches += trip.searches - _trip_searches.get(trip, 0)
		_nodes += trip.nodes_looked_at - _trip_nodes.get(trip, 0)
		_trip_searches[trip] = trip.searches
		_trip_nodes[trip] = trip.nodes_looked_at
	var snapshot: TravelSnapshot = _state.npcs._travel._snapshot
	if snapshot != _last_snapshot:
		_snapshots += 1
		_last_snapshot = snapshot


func _on_arrived(npc: Npc) -> void:
	_arrived += 1
	_sent_at.erase(npc)
	_searching_since.erase(npc)
	_next_send_at[npc] = _now + _rng.randf_range(0.0, REST_SECONDS)


func _on_blocked(_npc: Npc, reason: NpcTrip.Block) -> void:
	var word := NpcTrip.block_text(reason)
	_blocked_by_reason[word] = _blocked_by_reason.get(word, 0) + 1


func _print_run(seconds: float) -> void:
	print("main thread, ms a frame (mean / p99 / longest):")
	print("  Npcs.update's parts together  ", _stats(_total_ms))
	print("    walking                     ", _stats(_walk_ms))
	print("    pathfinder tick             ", _stats(_pathfinder_ms))
	print("    masks update                ", _stats(_masks_ms))
	print("    sending (walk_to)           ", _stats(_sending_ms))
	var slow := _total_ms.filter(func(ms: float) -> bool: return ms > SLOW_FRAME_MS).size()
	print("  probe (the same work)         ", _stats(_probe_ms))
	print("  %d of %d frames over %.1f ms" % [slow, _total_ms.size(), SLOW_FRAME_MS])
	print(
		(
			"trips sent %d, arrived %d, blocked %s; snapshots made %d"
			% [_sent, _arrived, _blocked_by_reason, _snapshots]
		)
	)
	print("waited for the first leg: ", _wait_stats())
	print(
		(
			"searches %d (%.2f a second), %d tiles looked at (%d a search), a worker busy %d %%"
			% [
				_searches,
				_searches / seconds,
				_nodes,
				_nodes / maxi(_searches, 1),
				roundi(100.0 * _nodes * SECONDS_A_TILE / seconds)
			]
		)
	)
	var travel: NpcTravel = _state.npcs._travel
	print(
		(
			"masks kept %d, raw chunks kept %d"
			% [travel._masks.mask_coords().size(), travel._masks.raw_chunk_coords().size()]
		)
	)
	_print_footprint()


## What a snapshot of the world costs now, and what the memory is.
func _print_footprint() -> void:
	var snapshot_started := Time.get_ticks_usec()
	var snapshot := TravelSnapshot.of(_state.world, 0)
	print(
		(
			"a snapshot now: %.3f ms, of %d worn tiles and %d building tiles"
			% [
				(Time.get_ticks_usec() - snapshot_started) / 1000.0,
				snapshot.wear.size(),
				snapshot.buildings.size()
			]
		)
	)
	print(
		(
			"static memory %.1f MB before, %.1f MB after, at most %.1f MB"
			% [
				_memory_before / 1048576.0,
				OS.get_static_memory_usage() / 1048576.0,
				_memory_peak / 1048576.0
			]
		)
	)


func _wait_stats() -> String:
	if _first_leg_waits.is_empty():
		return "none"
	return "mean %.2f s, longest %.2f s" % [_mean(_first_leg_waits), _first_leg_waits.max()]


## The mean, the 99th percentile and the longest of the times, in text.
func _stats(times: Array[float]) -> String:
	var sorted := times.duplicate()
	sorted.sort()
	return "%.3f / %.3f / %.3f" % [_mean(times), sorted[int(sorted.size() * 0.99)], sorted.back()]


func _mean(values: Array[float]) -> float:
	var sum := 0.0
	for value in values:
		sum += value
	return sum / values.size()
