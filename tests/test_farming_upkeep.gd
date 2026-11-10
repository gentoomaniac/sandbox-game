extends CropCase
## Soil and crops change every hour of the simulation, by a 24th of what a day does.


## A weather that gives every day the same summary and rains the same every hour.
class SteadyWeather:
	extends Weather
	var day := WeatherDay.new()

	func day_summary(_position: Vector2i, _day: int) -> WeatherDay:
		return day

	func rain_in_hour(_position: Vector2i, _day: int, _hour: int) -> float:
		return day.rain_hours / CropLife.HOURS_PER_DAY


var _state: GameState
var _weather: SteadyWeather
var _simulation: Simulation
var _farming: FarmingUpkeep
var _tile := Vector2i(3, 3)


func before_each() -> void:
	_state = GameState.new_game(7)
	_weather = SteadyWeather.new(7)
	_simulation = Simulation.new(_state.clock)
	_farming = FarmingUpkeep.new(_state.world, _weather)
	_simulation.add_system(_farming)
	_state.clock.set_time(0, 0)
	_state.world.set_terrain(_tile, Tile.Terrain.SOIL)


func _plant() -> WorldObject:
	var crop := WorldObject.new(WorldObjectTypes.TURNIP, _tile)
	crop.state["days_growing"] = 0
	_weather.day = _best_day(crop)
	_weather.day.rain_hours = 24.0  # keeps the soil soaked, as the whole day is tested on it
	_state.world.add_object(crop)
	_state.world.set_moisture(_tile, _best_moisture(crop))
	return crop


func test_a_crop_grows_a_little_every_hour_not_all_at_midnight() -> void:
	var crop := _plant()
	_simulation.advance(59)
	assert_eq(CropLife.growth(crop), 0.0, "the hour is not over")
	_simulation.advance(1)
	var after_one_hour := CropLife.growth(crop)
	assert_gt(after_one_hour, 0.0)
	_simulation.advance(60)
	assert_gt(CropLife.growth(crop), after_one_hour)


func test_a_day_of_hours_grows_a_crop_as_much_as_the_day_does() -> void:
	var crop := _plant()
	var whole_day := WorldObject.new(WorldObjectTypes.TURNIP, Vector2i.ZERO)
	_live_through_day(whole_day, _weather.day, _best_moisture(whole_day))
	_simulation.advance(GameClock.MINUTES_PER_DAY)
	assert_almost_eq(CropLife.growth(crop), CropLife.growth(whole_day), 0.0001)
	assert_eq(CropLife.days_growing(crop), 1, "the new day at midnight is counted")


func test_rain_in_an_hour_wets_and_the_hour_dries_the_soil() -> void:
	_state.world.set_moisture(_tile, 0.5)
	_weather.day.rain_hours = 24.0
	_simulation.advance(60)
	var change := _farming.moisture_change(_tile, 0)
	assert_gt(change, -0.01, "the rain wets more than the hour dries")
	assert_almost_eq(_state.world.moisture_at(_tile), 0.5 + change, 0.0001)


func test_the_soil_of_an_unloaded_chunk_changes_hourly_too() -> void:
	var far := Vector2i(900, 900)
	_state.world.add_chunk(WorldGenerator.new(7).generate_chunk(Chunk.world_to_chunk(far)))
	_state.world.set_terrain(far, Tile.Terrain.SOIL)
	_state.world.remove_chunk(Chunk.world_to_chunk(far))
	_state.world.set_moisture(far, 0.5)
	_weather.day.sunlight_hours = 10.0
	_simulation.advance(60)
	assert_lt(_state.world.moisture_at(far), 0.5)


func test_soil_read_once_after_a_month_equals_soil_read_every_hour() -> void:
	var stepped := GameState.new_game(7)
	var skipped := GameState.new_game(7)
	for state in [stepped, skipped]:
		state.world.set_terrain(_tile, Tile.Terrain.SOIL)
		state.world.set_moisture(_tile, 0.8)
	for _hour in 30 * 24:
		stepped.simulation.advance(60)
		stepped.world.moisture_at(_tile)
	skipped.simulation.advance(30 * 24 * 60)
	assert_almost_eq(skipped.world.moisture_at(_tile), stepped.world.moisture_at(_tile), 0.000001)


func test_the_moisture_that_is_saved_is_the_moisture_of_the_save() -> void:
	_state.world.set_moisture(_tile, 1.0)
	_weather.day.sunlight_hours = 12.0
	_simulation.advance(6 * 60)
	var moisture := _state.world.moisture_at(_tile)
	assert_lt(moisture, 1.0)
	var restored := GameState.from_dict(_state.to_dict())
	assert_almost_eq(restored.world.moisture_at(_tile), moisture, 0.0001)


## A crop planted at midnight, as ToolUse plants it, against one that lives through whole days as
## a night used to give them: at every midnight they are in the same state, so it ripens, waits and
## withers on the same days.
func test_the_days_of_a_crop_count_as_they_did_with_a_night_each() -> void:
	var crop := _plant()
	var nightly := WorldObject.new(WorldObjectTypes.TURNIP, Vector2i.ZERO)
	var moisture := _best_moisture(nightly)
	var ripe_day := -1
	var dead_day := -1
	for day in 40:
		_simulation.advance(GameClock.MINUTES_PER_DAY)
		_live_through_day(nightly, _weather.day, moisture)
		assert_eq(CropLife.days_growing(crop), CropLife.days_growing(nightly), "day %d" % day)
		assert_eq(CropLife.days_ripe(crop), CropLife.days_ripe(nightly), "day %d" % day)
		assert_eq(CropLife.is_dead(crop), CropLife.is_dead(nightly), "day %d" % day)
		assert_almost_eq(CropLife.growth(crop), CropLife.growth(nightly), 0.001)
		if CropLife.is_ripe(crop) and ripe_day < 0:
			ripe_day = day
		if CropLife.is_dead(crop) and dead_day < 0:
			dead_day = day
	assert_gt(ripe_day, 0, "it ripened")
	assert_gt(dead_day, ripe_day, "left ripe, it withered")


func test_soil_that_is_untilled_forgets_its_moisture() -> void:
	_state.world.set_moisture(_tile, 0.9)
	_state.world.set_terrain(_tile, Tile.Terrain.GRASS)
	_weather.day.sunlight_hours = 12.0
	_simulation.advance(10 * GameClock.MINUTES_PER_DAY)
	_state.world.set_terrain(_tile, Tile.Terrain.SOIL)
	assert_eq(
		_state.world.moisture_at(_tile), CropRules.default_rules().farming("default_moisture")
	)


func test_tiles_last_seen_in_different_hours_catch_up_as_hour_by_hour() -> void:
	var state := GameState.new_game(7)
	var seen_in_hour: Dictionary[Vector2i, int] = {}
	var start_hour := state.clock.total_minutes() / GameClock.MINUTES_PER_HOUR
	for index in 40:
		var pos := state.player.tile() + Vector2i(index % 8, index / 8 + 2)
		state.world.set_terrain(pos, Tile.Terrain.SOIL)
		state.world.set_moisture(pos, index / 40.0)
		seen_in_hour[pos] = start_hour + index
		state.simulation.advance(60)
	state.simulation.advance(30 * GameClock.MINUTES_PER_DAY)
	var now := state.clock.total_minutes() / GameClock.MINUTES_PER_HOUR
	for pos in seen_in_hour:
		var expected := (seen_in_hour[pos] - start_hour) / 40.0
		for hour in range(seen_in_hour[pos], now):
			expected = clampf(expected + state.world.soil.hourly_change.call(pos, hour), 0.0, 1.0)
		assert_almost_eq(state.world.moisture_at(pos), expected, 0.000001, str(pos))


func test_a_save_with_moisture_kept_for_a_tile_that_is_not_soil_loads_without_it() -> void:
	var data := _state.to_dict()
	var grass := _tile + Vector2i(0, 5)
	(data["world"]["soil_moisture"] as Array).append(SaveCodec.vector_to_json(grass) + [0.9])
	var restored := GameState.from_dict(data)
	assert_eq(
		restored.world.moisture_at(grass), CropRules.default_rules().farming("default_moisture")
	)
	var kept := restored.to_dict()["world"]["soil_moisture"] as Array
	assert_false(kept.any(func(entry: Array) -> bool: return entry[2] == 0.9))


## A crop from a save made before the hours has neither counter nor dawn note; it grows into
## ripeness during the day and the day still counts as a day of growing, as the night counted it.
func test_a_crop_of_an_old_save_counts_the_day_it_ripens_in_as_growing() -> void:
	var crop := WorldObject.new(WorldObjectTypes.TURNIP, Vector2i.ZERO)
	var ripe_growth: float = (
		(crop.type_data()["growth_stages"] - 1) * crop.type_data()["growth_per_stage"]
	)
	crop.state["growth"] = ripe_growth - 0.5
	var day := _best_day(crop)
	for _hour in CropLife.HOURS_PER_DAY:
		CropLife.live_through_hour(crop, day, _best_moisture(crop))
	assert_true(CropLife.is_ripe(crop), "it ripened during the day")
	CropLife.end_day(crop)
	assert_eq(CropLife.days_ripe(crop), 0)
	assert_eq(CropLife.days_growing(crop), int(ceil(ripe_growth - 0.5)) + 1)
