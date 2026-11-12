extends GutTest
## The gusts of wind that are heard: when a front of the gusts the plants sway in reaches the
## player, as loud as the wind, and none where the plants show none. The audio service is real;
## what it plays is recorded.

const STEP_SECONDS := 0.05
const WATCHED_SECONDS := 12.0

var _state: GameState
var _weather_view: WeatherView
var _ambience: AmbienceSounds
## The shader seconds at which a gust was heard.
var _gusts: Array[float] = []
var _shader_seconds := 0.0


func before_each() -> void:
	_state = GameState.new_game(7)
	var audio := AudioService.new()
	add_child_autofree(audio)
	audio.played.connect(
		func(event: StringName, _position: Variant) -> void:
			if event == &"wind_gust":
				_gusts.append(_shader_seconds)
	)
	var wildlife := WildlifeView.new()
	autofree(wildlife)
	wildlife.world_view = WorldView.new()
	add_child_autofree(wildlife.world_view)
	# As show_wildlife does: the ground is a Node2D nobody frees unless the world view owns it.
	wildlife.world_view.add_child(wildlife.ground)
	_weather_view = WeatherView.new()
	add_child_autofree(_weather_view)
	_ambience = AmbienceSounds.new()
	add_child_autofree(_ambience)
	_ambience.listen(audio, _state, wildlife, _weather_view)


## Lets the front of the shaders go by the player for a while, as the game does each frame.
func _watch_the_wind(wind: Vector2) -> void:
	_weather_view.wind = wind
	_shader_seconds = 0.0
	while _shader_seconds < WATCHED_SECONDS:
		_ambience._listen_for_gusts(_shader_seconds)
		_shader_seconds += STEP_SECONDS


func test_there_is_no_gust_in_wind_too_light_for_gusts_to_show() -> void:
	_watch_the_wind(Vector2.RIGHT * AmbientMotion.GUSTS_FROM)
	assert_eq(_gusts, [])


func test_a_gust_is_heard_each_time_a_front_arrives_at_the_player() -> void:
	var wind := Vector2.RIGHT * 10.0
	_watch_the_wind(wind)
	var player := _state.player.position * TerrainTileset.TILE_SIZE
	var front_spacing_seconds := AmbientMotion.GUST_SPACING / AmbientMotion.GUST_SPEED
	assert_gte(_gusts.size(), int(WATCHED_SECONDS / front_spacing_seconds), "one per front")
	for seconds in _gusts:
		var before := AmbientMotion.gust_front(player, wind.normalized(), seconds - STEP_SECONDS)
		var now := AmbientMotion.gust_front(player, wind.normalized(), seconds)
		assert_true(_ambience.rules.is_gust(now), "the front is over the player")
		assert_false(_ambience.rules.is_gust(before), "and arrived a moment ago")


func test_a_gust_swells_the_wind_loop_more_in_a_stronger_wind() -> void:
	_watch_the_wind(Vector2.RIGHT * 6.0)
	var light_swell := _ambience._wind_target
	_watch_the_wind(Vector2.RIGHT * 16.0)
	assert_gt(_ambience._wind_target, light_swell)


func test_the_gust_sound_is_an_ambience_that_is_turned_down_indoors() -> void:
	var values := SoundRules.default_rules().event(&"wind_gust")
	assert_eq(AudioService.BUS_OF_KEY[values["bus"]], AudioService.AMBIENCE)
