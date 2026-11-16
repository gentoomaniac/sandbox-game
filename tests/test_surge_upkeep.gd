extends GutTest
## The roll ahead of each high water (SurgeUpkeep) and the console's `surge` (#103).

const SEED := 7
const AUTUMN_DAY := 100

var _state: GameState
var _simulation: Simulation
var _weather: StormyWeather
var _comings: Array[float] = []


func before_each() -> void:
	_state = GameFactory.new_game(SEED)
	_weather = StormyWeather.new(SEED)
	_state.world.surge.coming.connect(
		func(level: float, _start: int) -> void: _comings.append(level)
	)
	_simulation = Simulation.new(_state.clock)
	_simulation.add_system(SurgeUpkeep.new(_state.world, _weather))
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


func _coast_simulation(world: World) -> Simulation:
	var simulation := Simulation.new(world.clock)
	simulation.add_system(SurgeUpkeep.new(world, StormyWeather.new(CoastWorld.SEED)))
	return simulation


func test_the_sea_runs_over_the_dykes_when_the_surge_starts() -> void:
	var world := CoastWorld.make()
	var simulation := _coast_simulation(world)
	world.surge.start_now(3.4, world.clock.total_minutes(), 180)
	simulation.advance(1)
	assert_true(world.flood.is_active())
	assert_eq(world.flood.level, 3.4)
	assert_eq(world.flood.wet_count(), 0, "the frames fill it a little at a time")
	world.flood.step_tiles(world, 50)
	assert_eq(world.flood.wet_count(), 50)


func test_a_skip_of_time_fills_the_flood_at_once_and_drains_it_when_its_stay_is_over() -> void:
	var world := CoastWorld.make()
	var simulation := _coast_simulation(world)
	world.surge.start_now(3.4, world.clock.total_minutes(), 180)
	simulation.skip(10 * GameClock.MINUTES_PER_HOUR)
	assert_gt(world.flood.wet_count(), 100)
	assert_eq(world.flood.phase, FloodState.Phase.STANDING)
	simulation.skip(2 * GameClock.MINUTES_PER_DAY)
	assert_eq(world.flood.wet_count(), 0)
	assert_eq(world.flood.phase, FloodState.Phase.IDLE)


func test_a_skip_longer_than_the_stay_still_wets_the_land_before_it_drains() -> void:
	var world := CoastWorld.make()
	var simulation := _coast_simulation(world)
	world.surge.start_now(3.4, world.clock.total_minutes(), 180)
	simulation.skip(3 * GameClock.MINUTES_PER_DAY)
	assert_eq(world.flood.wet_count(), 0, "drained")
	assert_eq(world.flood.phase, FloodState.Phase.IDLE)
	assert_gt(world.flood._salt_days.size(), 100, "but it was under water, and the salt is there")
