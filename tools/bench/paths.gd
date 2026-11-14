extends SceneTree
## What finding the way costs (task 238) with the villagers of a save, and how well they get
## there. First the villagers stand and stroll for 60 s of frames; then, in ROUNDS rounds of
## ROUND_SECONDS, villagers are sent 60 to 120 tiles to a tile they can stand on, while `Npcs.update`
## runs frame after frame at 60 fps of game time. Prints the mean and the longest `update` in
## milliseconds (and how many frames went over the budget of the searches, which counts the walking
## too); and for the trips how many there were, how many arrived and how long the whole trip took, how
## many were blocked (told, by reason) and how many were still on at the end of a round, and how long
## the villagers waited for their first leg: the mean and the longest, in seconds of game time.
## `make bench` writes the save (build/bench/fixture.save); this needs no Main.
## godot --headless --path . -s tools/bench/paths.gd -- <save file> [<key>=<number> ...]
## The keys after the save are numbers of [travel] (data/npcs.cfg) to try instead, such as
## `heuristic_weight=1.5 max_nodes=2000`, and `send=<n>`: how many villagers are sent in a round
## (the first n; default all of them, which is the worst case, an hour all villagers keep).

const FRAME_SECONDS := 1.0 / 60.0
const STANDING_SECONDS := 60.0
const ROUNDS := 3
const ROUND_SECONDS := 150.0
const REACH := Vector2i(60, 120)
const GOAL_TRIES := 30
const HOUR := 10
## The chunks loaded around the player, as many as in the save the game plays (13 x 13).
const CHUNK_RADIUS := 6

var _state: GameState
var _rng := RandomNumberGenerator.new()
var _send_count := 1000000
var _now := 0.0
var _trips := 0
## When each villager on a trip was sent, and (while its first search is on) when that began.
var _sent_at := {}
var _searching_since := {}
var _first_leg_waits: Array[float] = []
var _trip_times: Array[float] = []
var _unfinished := 0
var _blocked_by_reason := {}


func _init() -> void:
	_state = SaveFile.read(OS.get_cmdline_user_args()[0])
	_rng.seed = 1
	_state.clock.set_time(HOUR, 0)
	_load_chunks()
	var npcs := _state.npcs
	npcs.rules = _rules_with_arguments()
	npcs.trip_arrived.connect(_on_arrived)
	npcs.trip_blocked.connect(_on_blocked)
	print("villagers ", npcs.all().size())
	print("standing and strolling: ", _run_frames(STANDING_SECONDS, false))
	var times := ""
	for round in ROUNDS:
		_send_villagers()
		times = _run_frames(ROUND_SECONDS, true)
		_end_round()
	print("on trips (the last round): ", times)
	print(
		"trips ",
		_trips,
		" arrived ",
		_trip_times.size(),
		" (%d %%)" % roundi(100.0 * _trip_times.size() / maxi(_trips, 1)),
		" still on at the end ",
		_unfinished,
		" blocked, told ",
		_blocked_by_reason,
		"\nwhole trip: ",
		_stats(_trip_times),
		"\nwaited for the first leg: ",
		_stats(_first_leg_waits)
	)
	quit()


## The rules of data/npcs.cfg with the [travel] numbers of the command line.
func _rules_with_arguments() -> NpcRules:
	var values := DataFile.read_sections(NpcRules.DEFAULT_PATH)
	for argument in OS.get_cmdline_user_args().slice(1):
		var pair := argument.split("=")
		if pair[0] == "send":
			_send_count = int(pair[1])
		else:
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


## Runs `seconds` of frames; returns the update times as text.
func _run_frames(seconds: float, with_trips: bool) -> String:
	var times: Array[float] = []
	var frames := roundi(seconds / FRAME_SECONDS)
	for _frame in frames:
		_now += FRAME_SECONDS
		var started := Time.get_ticks_usec()
		_state.npcs.update(FRAME_SECONDS, _state.world, _state.player.position, _state.clock)
		times.append((Time.get_ticks_usec() - started) / 1000.0)
		if with_trips:
			_note_searches_done()
	var budget_ms := _state.npcs.rules.travel("search_usec_per_frame") / 1000.0
	var over := times.filter(func(ms: float) -> bool: return ms > budget_ms).size()
	return (
		"update mean %.3f ms, longest %.3f ms, %d of %d frames over %.1f ms"
		% [_mean(times), times.max(), over, frames, budget_ms]
	)


func _send_villagers() -> void:
	for npc in _state.npcs.all().slice(0, _send_count):
		var goal := _goal_for(npc)
		if goal != npc.tile():
			_trips += 1
			_sent_at[npc] = _now
			_searching_since[npc] = _now
			_state.npcs.walk_to(npc, goal, _state.world)


## The trips that are still on at the end of a round end there, so the next starts clean.
func _end_round() -> void:
	for npc: Npc in _sent_at.keys():
		_unfinished += 1
		_state.npcs.cancel_trip(npc)
	_sent_at.clear()
	_searching_since.clear()


## A tile 60 to 120 tiles from the villager that a villager can stand on, or where it is.
func _goal_for(npc: Npc) -> Vector2i:
	for _try in GOAL_TRIES:
		var distance := _rng.randf_range(REACH.x, REACH.y)
		var tile := (
			npc.tile() + Vector2i((Vector2.from_angle(_rng.randf() * TAU) * distance).round())
		)
		if Npcs.can_stand_at(_state.world, Vector2(tile) + Vector2(0.5, 0.5)):
			return tile
	return npc.tile()


## A villager whose first search is over (it walks, is blocked or has arrived) has waited its time.
func _note_searches_done() -> void:
	for npc: Npc in _searching_since.keys():
		if npc.trip == null or npc.trip.state != NpcTrip.State.SEARCHING:
			_first_leg_waits.append(_now - _searching_since[npc])
			_searching_since.erase(npc)


func _on_arrived(npc: Npc) -> void:
	if _sent_at.has(npc):
		_trip_times.append(_now - _sent_at[npc])
		_sent_at.erase(npc)
	_searching_since.erase(npc)


func _on_blocked(_npc: Npc, reason: NpcTrip.Block) -> void:
	var word := NpcTrip.block_text(reason)
	_blocked_by_reason[word] = _blocked_by_reason.get(word, 0) + 1


func _stats(values: Array[float]) -> String:
	if values.is_empty():
		return "none"
	return "mean %.1f s, longest %.1f s" % [_mean(values), values.max()]


func _mean(values: Array[float]) -> float:
	var sum := 0.0
	for value in values:
		sum += value
	return sum / values.size()
