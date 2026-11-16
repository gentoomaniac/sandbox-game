extends GutTest
## The roll ahead of each high water (SurgeUpkeep) and the console's `surge` (#103).

const SEED := 7
const AUTUMN_DAY := 100

var _state: GameState
var _simulation: Simulation
var _weather: StormyWeather
var _comings: Array[float] = []


func before_each() -> void:
	_state = GameState.new_game(SEED)
	_weather = StormyWeather.new(SEED)
	_state.world.surge.coming.connect(
		func(level: float, _start: int) -> void: _comings.append(level)
	)
	_simulation = Simulation.new(_state.clock)
	_simulation.add_system(SurgeUpkeep.new(_state.world.surge, SurgeRoll.new(SEED, _weather)))
	_state.clock.day = AUTUMN_DAY
	_comings.clear()


func test_a_surge_is_known_hours_before_the_high_water() -> void:
	_weather.storm = 0.35
	var surge := _state.world.surge
	_simulation.advance(GameClock.MINUTES_PER_DAY)
	assert_gt(_comings.size(), 0)
	assert_gt(surge.last_rolled_tide, SurgeRoll.tide_number_at(AUTUMN_DAY * 1440.0 - 1440.0))


func test_each_high_water_is_rolled_once() -> void:
	_weather.storm = 0.35
	_simulation.advance(2 * GameClock.MINUTES_PER_DAY)
	var tides := 2 * GameClock.MINUTES_PER_DAY / Tide.PERIOD_MINUTES
	assert_between(
		_comings.size(), int(tides), int(tides) + 2, "each high water, and those of the next hours"
	)


func test_no_storm_no_surge() -> void:
	_weather.storm = 0.0
	_simulation.advance(3 * GameClock.MINUTES_PER_DAY)
	assert_eq(_comings.size(), 0)
	assert_false(_state.world.surge.has_surge())


func test_the_surge_ends_once_the_water_has_fallen() -> void:
	_weather.storm = 0.35
	_simulation.advance(GameClock.MINUTES_PER_DAY)
	_weather.storm = 0.0
	_simulation.advance(GameClock.MINUTES_PER_DAY)
	assert_false(_state.world.surge.has_surge())


func test_the_surge_phases_follow_the_clock() -> void:
	var surge := _state.world.surge
	surge.expect(2.5, 1000, 180)
	assert_true(surge.is_expected_at(900))
	assert_false(surge.is_holding_at(900))
	assert_true(surge.is_holding_at(1000))
	assert_false(surge.is_holding_at(1100))
	assert_false(surge.is_expected_at(1100))


func test_the_surge_command_starts_shows_and_ends_one() -> void:
	var console := Console.new(_state)
	assert_eq(console.run("surge"), ["No surge expected"] as Array[String])
	assert_eq(console.run("surge 2.5"), ["A surge of 2.5 m starts now"] as Array[String])
	assert_true(_state.world.surge.is_holding_at(_state.clock.total_minutes()))
	assert_string_contains(console.run("surge")[0], "A surge of 2.5 m: the sea stands high until")
	assert_eq(console.run("surge off"), ["No surge"] as Array[String])
	assert_false(_state.world.surge.has_surge())
	assert_eq(console.run("surge x"), ["Usage: surge [metres|off]"] as Array[String])
