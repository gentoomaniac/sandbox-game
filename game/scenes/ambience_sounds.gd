class_name AmbienceSounds
extends Node
## The sound of the world around the player: rain and wind as loops that follow the weather (and
## swell with gusts), thunder after each flash of lightning, birds, frogs, the sounds of deer,
## rabbits and squirrels, bees buzzing where they hover, a stork's clatter, honking geese, the
## frogs' chorus on spring and summer evenings where frogs are about, and now and then an animal
## of the livestock: a cow, a sheep, a hen, a dog, a cat or a horse (not while it sleeps). The
## chances and levels are AmbienceRules'; which event an animal makes is SoundEvents'; playing is
## AudioService's.
##
## It is cheap by design: once a second it looks at the weather and rolls the dice for the
## chirps, croaks and animal sounds, finding the place of a chirp or a croak by looking at a few
## random tiles around the player, never at a whole area. The animals tell it when they appear
## and when they run, so it never scans them either. Everything of the outside world goes through
## the audio service's outside routing, so it is muffled while the player is in a house.
## Birds and frogs are silent indoors, where the map around the player is not the world's.
## Indoors the fire of a hearth crackles as the main sound: one positional loop per fire in the
## room, there while the player is in it (a fire is what AmbientMotion draws flames for; the oven
## burns none, and no fire goes out yet).

## The seconds between its looks at the weather and its rolls of the dice.
const TICK_SECONDS := 1.0

var rules := AmbienceRules.default_rules()
var _audio: AudioService
var _state: GameState
var _wildlife: WildlifeView
var _weather_view: WeatherView
var _rng := RandomNumberGenerator.new()
var _seconds_to_tick := 0.0
var _rain_loop: SoundLoop
var _wind_loop: SoundLoop
var _chorus_loop: SoundLoop
## What the loops are fading to now, to start a fade only when the target moves.
var _rain_target := 0.0
var _wind_target := 0.0
var _chorus_target := 0.0
## What the wind loop is at without a gust, as of the last look at the weather.
var _wind_level := 0.0
var _gust_seconds_left := 0.0
## How strong the gust that swells the wind loop was, 0 to 1 (AmbientMotion.gust_for).
var _gust_strength := 0.0
## Whether a gust front was over the player at the last frame, to hear a gust only as one arrives.
var _is_front_over := false
## The room the fire loops belong to (null in the world).
var _fire_room: Interior
## The loop of each fire that crackles.
var _fire_loops: Dictionary[WorldObject, SoundLoop] = {}
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
	_weather_view = weather_view
	weather_view.flashed.connect(_on_flash)
	wildlife.animal_added.connect(_on_animal_added)
	state.livestock.crowed.connect(
		func(rooster: FarmAnimal) -> void:
			_play_at(&"rooster_crow", rooster.position * TerrainTileset.TILE_SIZE)
	)


func _process(delta: float) -> void:
	_listen_for_gusts(AmbientMotion.shader_time())
	if (_state.current_map as Interior) != _fire_room:
		_follow_fires()
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
	_follow_frogs(weather)
	_follow_fires()
	if _state.is_inside():
		return
	var clock := _state.clock
	var season := clock.season()
	var phase := _wildlife.rules.phase(clock.day, clock.minute_of_day)
	if _rng.randf() < rules.bird_chance(season, phase, weather) * TICK_SECONDS:
		_chirp()
	_croak(season, phase, weather)
	_make_animal_sound()


## Makes the fires of the room the player is in crackle, and those of a room they left (or that
## are gone) go quiet. Run when the player changes rooms, and every tick.
func _follow_fires() -> void:
	_fire_room = _state.current_map as Interior
	var fade_seconds := rules.value("indoors", "fire_fade_seconds")
	var fires: Array[WorldObject] = []
	if _fire_room != null:
		fires = _fire_room.objects().filter(
			func(object: WorldObject) -> bool: return AmbientMotion.has_flames(object.type)
		)
	for fire in _fire_loops.keys():
		if not fires.has(fire):
			_fire_loops[fire].stop(fade_seconds)
			_fire_loops.erase(fire)
	for fire in fires:
		if not _fire_loops.has(fire):
			var footprint: Vector2i = fire.type_data()["footprint"]
			var middle := (Vector2(fire.pos) + Vector2(footprint) / 2.0) * TerrainTileset.TILE_SIZE
			var reach := rules.fire_reach(_fire_room.size) * TerrainTileset.TILE_SIZE
			var loop := _audio.start_loop(&"fire_crackle_loop", middle, 0.0, reach)
			loop.fade_to(rules.value("indoors", "fire_level"), fade_seconds)
			_fire_loops[fire] = loop


## Makes the loops follow the weather.
func _follow_weather(weather: WeatherSample) -> void:
	var fade_seconds := rules.value("loops", "fade_seconds")
	var rain_level := rules.rain_level(weather)
	_rain_loop = _follow(_rain_loop, &"rain_loop", rain_level, _rain_target, fade_seconds)
	_rain_target = rain_level

	_wind_level = rules.wind_level(weather)
	var was_gusting := _gust_seconds_left > 0.0
	_gust_seconds_left -= TICK_SECONDS
	if (_gust_seconds_left > 0.0) != was_gusting:
		fade_seconds = rules.value("loops", "gust_fade_seconds")
	_follow_wind(fade_seconds)


## Makes the wind loop follow the wind, swelling while a gust lasts.
func _follow_wind(fade_seconds: float) -> void:
	var wind_target := _wind_level
	if _gust_seconds_left > 0.0:
		wind_target += rules.value("loops", "gust_swell") * _gust_strength
	_wind_loop = _follow(_wind_loop, &"wind_loop", wind_target, _wind_target, fade_seconds)
	_wind_target = wind_target


## Plays a gust as a front of the gusts the plants sway in arrives at the player: the shaders'
## formula, for the wind and the time (`shader_seconds`, see AmbientMotion.shader_time) they use.
## There is none while the wind is too light for gusts to show.
func _listen_for_gusts(shader_seconds: float) -> void:
	var wind := _weather_view.wind
	var strength := AmbientMotion.gust_for(wind.length())
	var front := 0.0
	if strength > 0.0:
		var player := _state.player.position * TerrainTileset.TILE_SIZE
		front = AmbientMotion.gust_front(player, wind.normalized(), shader_seconds)
	var is_over := rules.is_gust(front)
	if is_over and not _is_front_over:
		_gust_strength = strength
		_gust_seconds_left = rules.value("loops", "gust_seconds")
		_audio.play(&"wind_gust", null, false, rules.gust_level(strength))
		_follow_wind(rules.value("loops", "gust_fade_seconds"))
	_is_front_over = is_over


## Starts, fades or stops a weather loop (or the frogs' chorus) so that it is at `level`.
## `old_level` is what it was fading to. Returns the loop (null once it is stopped).
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


## Makes the frogs' chorus follow the frogs about (none indoors, where the wildlife is cleared
## away), the season, the hour and the warmth.
func _follow_frogs(weather: WeatherSample) -> void:
	var frogs := 0
	for animal in _animals:
		if animal.kind == WildlifeRules.FROG and not animal.is_done:
			frogs += 1
	var clock := _state.clock
	var phase := _wildlife.rules.phase(clock.day, clock.minute_of_day)
	var level := rules.chorus_level(clock.season(), phase, weather.temperature, frogs)
	var fade_seconds := rules.value("frog_chorus", "fade_seconds")
	_chorus_loop = _follow(_chorus_loop, &"frog_chorus_loop", level, _chorus_target, fade_seconds)
	_chorus_target = level


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
			_play_at(&"bird_chirp", TerrainTileset.tile_centre(tile))
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
		_play_at(&"frog_croak", TerrainTileset.tile_centre(nearest))


## One of the animals about makes the sound of its kind, if it is one that does.
func _make_animal_sound() -> void:
	if _animals.is_empty():
		return
	var animal := _animals[_rng.randi() % _animals.size()]
	if animal.is_asleep:
		return
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
