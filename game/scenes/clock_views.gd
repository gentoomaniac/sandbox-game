class_name ClockViews
extends RefCounted
## What the views show of the time and the weather: the sky's tint, the clock, the ground cover and
## the looks that follow the day, the weather, the soil and the tide, and the position readout.
## `show_clock` is what changes with the minute, the map or a console command; `update` is each
## frame's. Main calls both.

var _state: GameState
var _view: WorldView
var _tint: DayNightTint
var _hud: ClockHud
var _player_view: PlayerView
var _weather_view: WeatherView
var _camera: CameraController
var _coordinates_hud: CoordinatesHud
var _weather: WeatherSample
var _snow_cover := 0.0
var _frost := 0.0
## The game hour the wetness of the soil was last shown for.
var _soil_shown_hour := -1


func _init(
	state: GameState,
	view: WorldView,
	tint: DayNightTint,
	hud: ClockHud,
	player_view: PlayerView,
	weather_view: WeatherView,
	camera: CameraController,
	coordinates_hud: CoordinatesHud
) -> void:
	_state = state
	_view = view
	_tint = tint
	_hud = hud
	_player_view = player_view
	_weather_view = weather_view
	_camera = camera
	_coordinates_hud = coordinates_hud


func show_clock() -> void:
	# The weather only changes with the minute, the map or a console command, which all end here.
	_weather = _state.current_weather()
	if _state.is_inside():
		_tint.show_interior()
	else:
		_tint.show_time(_state.clock, _weather.cloud_cover)
	_view.set_light_strength(_tint.light_strength())
	_view.set_sail_speed(_state.weather.mill_speed(_weather.wind_speed))
	_player_view.light_strength = _tint.light_strength()
	# The ground, the plants and the houses follow the weather by the minute, by shader; their
	# pictures only change with the day.
	_snow_cover = _state.current_snow_cover()
	_frost = _state.current_frost()
	var thaw := _state.current_thaw()
	_view.show_ground_cover(_state.clock.day, _snow_cover, thaw, _frost)
	_state.world.footprints.advance_to(
		_state.clock.total_minutes(), _weather.rain, _weather.snow, thaw
	)
	_view.refresh_looks(_state.clock.day)
	_hud.show_time(_state.clock)


func update(delta: float) -> void:
	var hour := _state.clock.total_minutes() / GameClock.MINUTES_PER_HOUR
	if hour != _soil_shown_hour:
		_soil_shown_hour = hour
		_view.refresh_soil(_state.last_hour_rain())
		_state.refresh_mud()
	_weather_view.visible_region = _camera.visible_region()
	_weather_view.show_weather(_weather, _tint.color, _tint.daylight)
	_view.ambient_motion.update(delta, _weather_view.wind, _weather_view.rain)
	_view.ambient_motion.show_tide(Tide.level(_state.clock.total_minutes()))
	if _coordinates_hud.visible:
		_coordinates_hud.show_position(
			_state.player.tile(),
			_state.is_inside(),
			CoordinatesHud.weather_and_sun_text(
				_weather, _state.sun, _state.clock.day, _snow_cover, _frost
			)
		)
