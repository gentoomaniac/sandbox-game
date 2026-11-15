extends ResourceCase
## Worn ground turns to mud in the rain and dries out again, and the player walks slower on it.

const ONE_TILE_SECONDS := 1.0 / PlayerState.SPEED

var _rules := PathRules.default_rules()
var _path: Vector2i


func before_each() -> void:
	super.before_each()
	_path = _tile + Vector2i.RIGHT
	_world.set_wear_days(_path, _rules.path_after_days())


func test_worn_ground_is_mud_in_the_rain_and_other_ground_is_not() -> void:
	_world.set_muddy(true)
	assert_true(_world.is_muddy_at(_path))
	assert_false(_world.is_muddy_at(_tile), "unworn grass")
	_world.set_muddy(false)
	assert_false(_world.is_muddy_at(_path), "dried out")


func test_trodden_grass_is_mud_too() -> void:
	var trodden := _tile + Vector2i.LEFT
	_world.set_wear_days(trodden, _rules.trodden_after_days())
	_world.set_muddy(true)
	assert_true(_world.is_muddy_at(trodden))


func test_the_worn_tiles_are_drawn_again_when_the_mud_comes_and_goes_and_no_others() -> void:
	watch_signals(_world)
	_world.set_muddy(true)
	assert_signal_emit_count(_world, "tile_changed", 1)
	assert_signal_emitted_with_parameters(_world, "tile_changed", [_path])
	_world.set_muddy(true)
	assert_signal_emit_count(_world, "tile_changed", 1, "nothing changed")
	_world.set_muddy(false)
	assert_signal_emit_count(_world, "tile_changed", 2)


func test_rain_makes_mud_and_a_clear_sky_dries_it() -> void:
	_state.weather_override = &"rain"
	_state.refresh_mud()
	assert_true(_world.is_muddy)
	_state.weather_override = &"clear"
	_state.refresh_mud()
	assert_false(_world.is_muddy)


func test_the_rain_of_the_last_hours_makes_mud_by_the_data() -> void:
	var was_muddy := false
	var was_dry := false
	for day in range(1, 120):
		for hour in range(0, 24, 5):
			_state.clock.day = day
			_state.clock.minute_of_day = hour * GameClock.MINUTES_PER_HOUR
			_state.refresh_mud()
			assert_eq(
				_world.is_muddy,
				_rain_before_now() >= _rules.soaked_by(),
				"day %d %d h" % [day, hour]
			)
			was_muddy = was_muddy or _world.is_muddy
			was_dry = was_dry or not _world.is_muddy
	assert_true(was_muddy and was_dry, "the weather of a year has both")


func _rain_before_now() -> float:
	var now_hour := _state.clock.total_minutes() / GameClock.MINUTES_PER_HOUR
	var rain := 0.0
	for hour in range(maxi(now_hour - _rules.window_hours(), 0), now_hour):
		rain += _state.weather.rain_in_hour(_state.player.tile(), hour / 24 + 1, hour % 24)
	return rain


func test_the_player_walks_slower_on_mud() -> void:
	_state.player.position = Vector2(_path) + Vector2(0.5, 0.5)
	var dry := _state.walk_speed_factor()
	_world.set_muddy(true)
	assert_almost_eq(_state.walk_speed_factor(), dry * _rules.walk_factor(), 0.0001)
	assert_lt(_state.walk_speed_factor(), dry)


func test_the_player_walks_at_full_speed_on_unworn_ground_in_the_rain() -> void:
	_world.set_muddy(true)
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	assert_eq(_state.walk_speed_factor(), 1.0)


func test_a_walk_over_mud_goes_less_far() -> void:
	_world.set_wear_days(_path + Vector2i.RIGHT, _rules.path_after_days())
	_world.remove_object(_path)
	_world.remove_object(_path + Vector2i.RIGHT)
	var start := Vector2(_path) + Vector2(0.1, 0.5)
	_state.player.position = start
	_state.walk(Vector2.RIGHT, ONE_TILE_SECONDS / 2, _state.walk_speed_factor())
	var dry_distance := _state.player.position.x - start.x
	_world.set_muddy(true)
	_state.player.position = start
	_state.walk(Vector2.RIGHT, ONE_TILE_SECONDS / 2, _state.walk_speed_factor())
	assert_almost_eq(
		_state.player.position.x - start.x, dry_distance * _rules.walk_factor(), 0.0001
	)
