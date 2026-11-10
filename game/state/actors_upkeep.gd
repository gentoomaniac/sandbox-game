class_name ActorsUpkeep
extends SimulationSystem
## The farm animals and the villagers while time skips (see Simulation `skip`). While the game
## is played they walk by the frame (Livestock and Npcs `update`, in real seconds), and nothing
## here moves them. The first minutes of a skip are walked through as the same seconds of play,
## minute by minute with the clock; what is left is made up for at once: each of them is put
## somewhere its time of day could have led it (their `catch_up`), by dice thrown from the world
## seed and the time, so that the same game skipped the same way ends the same. Only those in
## loaded chunks move, as in play: the others stay as they are.

var _world: World
var _livestock: Livestock
var _npcs: Npcs
## Where the player is, or Vector2.INF when indoors, for the animals that run from them or
## follow them.
var _player_feet: Callable


func _init(world: World, livestock: Livestock, npcs: Npcs, player_feet: Callable) -> void:
	_world = world
	_livestock = livestock
	_npcs = npcs
	_player_feet = player_feet


## No hunts: a skip's walked minutes keep the cats from looking for a mouse of a view that is
## held, and end a hunt that was on.
func walked_minute(clock: GameClock) -> void:
	var seed_value := _seed_of(clock, 1)
	_livestock.rng.seed = seed_value
	_npcs.rng.seed = seed_value
	var seconds := 1.0 / GameClock.GAME_MINUTES_PER_REAL_SECOND
	while seconds > 0.0:
		var step := minf(seconds, Livestock.MAX_STEP_SECONDS)
		_livestock.update(step, _world, _player_feet.call(), clock, true, false)
		_npcs.update(step, _world, _player_feet.call(), clock, true)
		seconds -= step


func skipped(_minutes: int, clock: GameClock) -> void:
	_livestock.catch_up(_world, clock, _player_feet.call(), _seed_of(clock, 2))
	_npcs.catch_up(_world, _seed_of(clock, 3))


func skipped_over_frames(_minutes: int, clock: GameClock, next_frame: Callable) -> void:
	_livestock.catch_up(_world, clock, _player_feet.call(), _seed_of(clock, 2))
	await _npcs.catch_up_over_frames(_world, _seed_of(clock, 3), next_frame)


## The dice of `purpose` at the time of `clock` in this world.
func _seed_of(clock: GameClock, purpose: int) -> int:
	return hash([_world.world_seed, clock.total_minutes(), purpose])
