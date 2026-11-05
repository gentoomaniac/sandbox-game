extends ResourceCase
## The weather in the game state (the player's place, the forced condition) and the console's
## `weather` command.

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


func test_the_weather_is_the_one_at_the_players_place_and_time() -> void:
	var expected := _state.weather.at(
		_state.player.tile(), _state.clock.day, _state.clock.minute_of_day
	)
	assert_eq(_state.current_weather().temperature, expected.temperature)


func test_the_weather_follows_the_clock() -> void:
	var before := _state.current_weather().temperature
	_state.clock.advance(5 * GameClock.MINUTES_PER_DAY + 400)
	assert_ne(_state.current_weather().temperature, before)


func test_inside_a_house_the_weather_is_the_one_outside_its_door() -> void:
	var house := _place_house()
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_true(_state.is_inside())
	var outside := _state.weather.at(
		house.door_tile(), _state.clock.day, _state.clock.minute_of_day
	)
	assert_eq(_state.current_weather().temperature, outside.temperature)


func test_a_new_game_and_a_loaded_one_have_the_same_weather() -> void:
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	assert_eq(restored.current_weather().temperature, _state.current_weather().temperature)


func test_a_forced_condition_replaces_the_simulation_and_auto_ends_it() -> void:
	assert_eq(_console.run("weather rain"), _lines("Weather forced to rain (weather auto ends it)"))
	assert_gt(_state.current_weather().rain, 0.0)
	assert_eq(_console.run("weather auto"), _lines("Weather follows the simulation"))
	assert_eq(_state.weather_override, &"")


func test_the_override_is_not_saved() -> void:
	_state.weather_override = &"snow"
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	assert_eq(restored.weather_override, &"")


func test_weather_alone_prints_values_conditions_and_the_sun() -> void:
	_console.run("weather thunder")
	var text := "\n".join(_console.run("weather"))
	assert_string_contains(text, "humidity")
	assert_string_contains(text, "Conditions: ")
	assert_string_contains(text, "thunder")
	assert_string_contains(text, "Sun: ")
	assert_string_contains(text, "Forced: thunder")


func test_every_condition_can_be_forced() -> void:
	for condition in Weather.FORCEABLE:
		_console.run("weather %s" % condition)
		assert_eq(_state.weather_override, condition)


func test_a_wrong_weather_argument_shows_the_usage() -> void:
	var usage := _console.run("weather hail")
	assert_string_contains(usage[0], "Usage: weather")
	assert_eq(_state.weather_override, &"")
	assert_string_contains(_console.run("weather rain snow")[0], "Usage: weather")


func test_help_lists_weather_and_tab_completes_its_arguments() -> void:
	assert_string_contains("\n".join(_console.run("help")), "weather")
	assert_eq(_console.complete("wea"), "weather ")
	assert_eq(_console.complete("weather th"), "weather thunder ")
	assert_eq(_console.complete("weather a"), "weather auto ")


func _place_house() -> Building:
	for x in range(-SEARCH, SEARCH):
		for y in range(-SEARCH, SEARCH):
			var house := _world.place_building(
				BuildingTypes.SMALL_HOUSE, _state.player.tile() + Vector2i(x, y)
			)
			if house != null:
				return house
	fail_test("no room for a house near the camp")
	return null


func _lines(text: String) -> Array[String]:
	return [text] as Array[String]
