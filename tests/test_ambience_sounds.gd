extends GutTest
## The ambience node: the weather loops start and stop with the weather, thunder follows a flash
## after a delay, a bee that appears buzzes, and a farm animal calls only while it is awake. The
## audio service is real; what it plays is recorded.

var _state: GameState
var _audio: AudioService
var _ambience: AmbienceSounds
var _wildlife: WildlifeView
var _weather_view: WeatherView
var _events: Array[StringName] = []


func before_each() -> void:
	_state = GameState.new_game(7)
	_audio = AudioService.new()
	add_child_autofree(_audio)
	_audio.played.connect(
		func(event: StringName, _position: Variant) -> void: _events.append(event)
	)
	_wildlife = WildlifeView.new()
	autofree(_wildlife)
	_wildlife.rules = WildlifeRules.default_rules()
	_wildlife.rules.sun = _state.sun
	_wildlife.world_view = WorldView.new()
	add_child_autofree(_wildlife.world_view)
	# As show_wildlife does: the ground is a Node2D nobody frees unless the world view owns it.
	_wildlife.world_view.add_child(_wildlife.ground)
	_weather_view = WeatherView.new()
	add_child_autofree(_weather_view)
	_ambience = AmbienceSounds.new()
	add_child_autofree(_ambience)
	_ambience.listen(_audio, _state, _wildlife, _weather_view)
	_events.clear()


func test_rain_and_wind_loops_start_with_a_storm_and_stop_when_it_clears() -> void:
	_state.weather_override = &"storm"
	_ambience._process(1.0)
	assert_true(_events.has(&"rain_loop"))
	assert_true(_events.has(&"wind_loop"))
	_events.clear()
	_state.weather_override = &"clear"
	_ambience._process(1.0)
	assert_eq(_events, [], "nothing new starts")
	assert_null(_ambience._rain_loop)


func test_a_clear_calm_day_has_no_loops() -> void:
	_state.weather_override = &"clear"
	_ambience._process(1.0)
	assert_false(_events.has(&"rain_loop"))


## The ambience rules of the data file with the thunder coming within 0.1 to 0.2 s.
func _quick_thunder_rules() -> AmbienceRules:
	var values := DataFile.read_sections(AmbienceRules.DEFAULT_PATH)
	values["thunder"] = {"min_delay_seconds": 0.1, "max_delay_seconds": 0.2}
	return AmbienceRules.new(values)


func test_thunder_follows_a_flash_after_a_delay() -> void:
	_ambience.rules = _quick_thunder_rules()
	_weather_view.flash()
	assert_false(_events.has(&"thunder"), "not at once")
	await wait_seconds(0.3)
	assert_true(_events.has(&"thunder"))


func test_a_bee_buzzes_where_it_is() -> void:
	_add_bee(Vector2(1, 1))
	_ambience._process(1.0)
	assert_true(_events.has(&"bee_buzz_loop"))


func test_a_buzzing_bee_that_flies_out_of_hearing_goes_quiet() -> void:
	var bee := _add_bee(Vector2(1, 1))
	_ambience._process(1.0)
	assert_eq(_ambience._bee_loops.size(), 1)
	var reach: float = AmbienceRules.default_rules().value("bees", "hear_tiles")
	bee.position += Vector2(reach + 2.0, 0) * TerrainTileset.TILE_SIZE
	_ambience._process(1.0)
	assert_eq(_ambience._bee_loops.size(), 0)


func test_a_bee_out_of_hearing_is_quiet() -> void:
	var reach: float = AmbienceRules.default_rules().value("bees", "hear_tiles")
	_add_bee(Vector2(reach + 1.0, 0))
	_ambience._process(1.0)
	assert_false(_events.has(&"bee_buzz_loop"))


## Adds a bee `offset_tiles` away from the player and returns it.
func _add_bee(offset_tiles: Vector2) -> Bee:
	var bee := Bee.new()
	autofree(bee)
	bee.wildlife = _wildlife
	bee.position = (_state.player.position + offset_tiles) * TerrainTileset.TILE_SIZE
	_ambience._on_animal_added(bee)
	return bee


func test_a_cow_moos_now_and_then_but_not_in_its_sleep() -> void:
	var cow := FarmAnimal.new(LivestockRules.COW, &"angler", _state.player.position)
	var cow_view := FarmAnimalView.new(cow)
	add_child_autofree(cow_view)
	cow_view._update(0.0)
	_ambience._on_animal_added(cow_view)
	for _second in 1000:
		_ambience._make_animal_sound()
	assert_true(_events.has(&"cow_moo"))

	_events.clear()
	cow.activity = FarmAnimal.Activity.SLEEP
	cow_view._update(0.0)
	for _second in 1000:
		_ambience._make_animal_sound()
	assert_false(_events.has(&"cow_moo"))
