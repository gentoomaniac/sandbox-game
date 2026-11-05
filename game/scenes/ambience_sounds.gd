class_name AmbienceSounds
extends Node
## The sound of the world around the player: rain and wind as loops that follow the weather (and
## swell with gusts), thunder after each flash of lightning, birds, frogs, the sounds of deer,
## rabbits and squirrels, and bees buzzing where they hover. The chances and levels are
## AmbienceRules'; which event an animal makes is SoundEvents'; playing is AudioService's.
##
## It is cheap by design: once a second it looks at the weather and rolls the dice for the
## chirps, croaks and animal sounds, finding the place of a chirp or a croak by looking at a few
## random tiles around the player, never at a whole area. The animals tell it when they appear
## and when they run, so it never scans them either. Everything of the outside world goes through
## the audio service's outside routing, so it is muffled while the player is in a house.
## Birds and frogs are silent indoors, where the map around the player is not the world's.

## The seconds between its looks at the weather and its rolls of the dice.
const TICK_SECONDS := 1.0

var rules := AmbienceRules.default_rules()
var _audio: AudioService
var _state: GameState
var _wildlife: WildlifeView
var _rng := RandomNumberGenerator.new()
var _seconds_to_tick := 0.0
var _rain_loop: SoundLoop
var _wind_loop: SoundLoop
## What the loops are fading to now, to start a fade only when the target moves.
var _rain_target := 0.0
var _wind_target := 0.0
var _gust_seconds_left := 0.0
var _animals: Array[Animal] = []
## The loop of each bee that buzzes.
var _bee_loops: Dictionary[Animal, SoundLoop] = {}


func _init() -> void:
	_rng.randomize()


## Starts listening: to the weather view's flashes, and to the animals of `wildlife` as they
## appear.
func listen(
	audio: AudioService, state: GameState, wildlife: WildlifeView, weather_view: WeatherView
) -> void:
	_audio = audio
	_state = state
	_wildlife = wildlife
	weather_view.flashed.connect(_on_flash)
	wildlife.animal_added.connect(_on_animal_added)


func _process(delta: float) -> void:
	for animal in _bee_loops:
		_bee_loops[animal].move_to(animal.position)
	_seconds_to_tick -= delta
	if _seconds_to_tick <= 0.0:
		_seconds_to_tick += TICK_SECONDS
		_tick()


func _tick() -> void:
	var weather := _state.current_weather()
	_follow_weather(weather)
	_buzz_bees()
	if _state.is_inside():
		return
	var clock := _state.clock
	var season := clock.season()
	var phase := _wildlife.rules.phase(clock.day, clock.minute_of_day)
	if _rng.randf() < rules.bird_chance(season, phase, weather) * TICK_SECONDS:
		_chirp()
	_croak(season, phase, weather)
	_make_animal_sound()


## Makes the loops follow the weather, and starts a gust now and then.
func _follow_weather(weather: WeatherSample) -> void:
	var fade_seconds := rules.value("loops", "fade_seconds")
	var rain_level := rules.rain_level(weather)
	_rain_loop = _follow(_rain_loop, &"rain_loop", rain_level, _rain_target, fade_seconds)
	_rain_target = rain_level

	var wind_level := rules.wind_level(weather)
	var was_gusting := _gust_seconds_left > 0.0
	_gust_seconds_left -= TICK_SECONDS
	if wind_level > 0.0 and _rng.randf() < rules.gust_chance(wind_level) * TICK_SECONDS:
		_gust_seconds_left = rules.value("loops", "gust_seconds")
		_audio.play(&"wind_gust")
	var is_gusting := _gust_seconds_left > 0.0
	if is_gusting != was_gusting:
		fade_seconds = rules.value("loops", "gust_fade_seconds")
	var wind_target := wind_level
	if is_gusting:
		wind_target += rules.value("loops", "gust_swell")
	_wind_loop = _follow(_wind_loop, &"wind_loop", wind_target, _wind_target, fade_seconds)
	_wind_target = wind_target


## Starts, fades or stops a weather loop so that it is at `level`. `old_level` is what it was
## fading to. Returns the loop (null once it is stopped).
func _follow(
	loop: SoundLoop, event: StringName, level: float, old_level: float, fade_seconds: float
) -> SoundLoop:
	var min_level := rules.value("loops", "min_level")
	if level < min_level:
		if loop != null:
			loop.stop(fade_seconds)
		return null
	if loop == null:
		loop = _audio.start_loop(event, null, 0.0)
		old_level = 0.0
	if not is_equal_approx(level, old_level):
		loop.fade_to(level, fade_seconds)
	return loop


## Thunder follows the flash after a while, as from a far-off strike.
func _on_flash() -> void:
	var delay := rules.thunder_delay(_rng)
	get_tree().create_timer(delay, false).timeout.connect(func() -> void: _audio.play(&"thunder"))


## A chirp from a bird that is about, else from a tree near the player.
func _chirp() -> void:
	var birds := _animals.filter(
		func(animal: Animal) -> bool: return animal.kind == WildlifeRules.BIRD
	)
	if not birds.is_empty():
		_play_at(&"bird_chirp", birds[_rng.randi() % birds.size()].position)
		return
	var tries := int(rules.value("birds", "tries"))
	var radius := int(rules.value("birds", "radius_tiles"))
	for tile in _random_tiles(radius, tries):
		var object := _state.world.object_at(tile)
		if object != null and WildlifeRules.TREE_TYPES.has(object.type):
			_play_at(&"bird_chirp", _centre_of(tile))
			return


## A frog croaks at the nearest water of a few tiles looked at around the player.
func _croak(season: GameClock.Season, phase: WildlifeRules.Phase, weather: WeatherSample) -> void:
	var radius := int(rules.value("frogs", "radius_tiles"))
	var player := _state.player.position
	var nearest := Vector2i.ZERO
	var nearest_distance := INF
	for tile in _random_tiles(radius, int(rules.value("frogs", "tries"))):
		var ground := _state.world.tile_at(tile)
		if ground == null or not AmbienceRules.FROG_TERRAINS.has(ground.terrain):
			continue
		var distance := player.distance_to(Vector2(tile) + Vector2(0.5, 0.5))
		if distance < nearest_distance:
			nearest = tile
			nearest_distance = distance
	if nearest_distance == INF:
		return
	var chance := rules.frog_chance(season, phase, weather.temperature, nearest_distance)
	if _rng.randf() < chance * TICK_SECONDS:
		_play_at(&"frog_croak", _centre_of(nearest))


## One of the animals about makes the sound of its kind, if it is one that does.
func _make_animal_sound() -> void:
	if _animals.is_empty():
		return
	var animal := _animals[_rng.randi() % _animals.size()]
	var event := SoundEvents.animal_idle(animal.kind)
	if event != &"" and _rng.randf() < rules.idle_chance(animal.kind) * TICK_SECONDS:
		_play_at(event, animal.position)


## Makes the nearest bees buzz (as many as the rules allow) and lets the others go quiet.
func _buzz_bees() -> void:
	var player := _state.player.position * TerrainTileset.TILE_SIZE
	var reach: float = rules.value("bees", "hear_tiles") * TerrainTileset.TILE_SIZE
	var bees := _animals.filter(
		func(animal: Animal) -> bool:
			return animal.kind == WildlifeRules.BEE and animal.position.distance_to(player) < reach
	)
	bees.sort_custom(
		func(a: Animal, b: Animal) -> bool:
			return a.position.distance_squared_to(player) < b.position.distance_squared_to(player)
	)
	var buzzing := bees.slice(0, int(rules.value("bees", "max_loops")))
	for bee: Animal in _bee_loops.keys():
		if not buzzing.has(bee):
			_bee_loops[bee].stop(1.0)
			_bee_loops.erase(bee)
	for bee: Animal in buzzing:
		if not _bee_loops.has(bee):
			_bee_loops[bee] = _audio.start_loop(
				&"bee_buzz_loop", bee.position, rules.value("bees", "level"), reach
			)


func _on_animal_added(animal: Animal) -> void:
	_animals.append(animal)
	animal.state_entered.connect(
		func(state: StringName) -> void:
			var event := SoundEvents.animal_alarm(animal.kind, state)
			if event != &"":
				_play_at(event, animal.position)
	)
	animal.tree_exiting.connect(
		func() -> void:
			_animals.erase(animal)
			if _bee_loops.has(animal):
				_bee_loops[animal].stop(0.3)
				_bee_loops.erase(animal)
	)


## Plays an event of the outside world at a place, in world art pixels.
func _play_at(event: StringName, position: Vector2) -> void:
	_audio.play(event, position, true)


## `count` random tiles within `radius` tiles of the player.
func _random_tiles(radius: int, count: int) -> Array[Vector2i]:
	var centre := _state.player.tile()
	var tiles: Array[Vector2i] = []
	for _try in count:
		tiles.append(
			centre + Vector2i(_rng.randi_range(-radius, radius), _rng.randi_range(-radius, radius))
		)
	return tiles


func _centre_of(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TerrainTileset.TILE_SIZE
