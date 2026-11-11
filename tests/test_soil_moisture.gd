extends ResourceCase
## Soil moisture: rain wets tilled soil, the watering can fills it, the day dries it, it is
## saved, and it shows as a darker look.


## A weather that gives every day the same summary.
class SteadyWeather:
	extends Weather
	var day := WeatherDay.new()

	func day_summary(_position: Vector2i, _day: int) -> WeatherDay:
		return day

	func rain_in_hour(_position: Vector2i, _day: int, _hour: int) -> float:
		return day.rain_hours / CropLife.HOURS_PER_DAY


var _weather: SteadyWeather
## Kept, as the soil only knows its weather by it.
var _farming_upkeep: FarmingUpkeep


func before_each() -> void:
	super.before_each()
	_weather = SteadyWeather.new(SEED)
	_state.clock.day = 5
	_world.set_terrain(_tile, Tile.Terrain.SOIL)


## A whole day over the soil and the crops, hour by hour, then the night.
func _pass_night() -> void:
	_farming_upkeep = FarmingUpkeep.new(_world, _weather)
	var first_hour := (_state.clock.day - 1) * CropLife.HOURS_PER_DAY
	for hour in range(first_hour, first_hour + CropLife.HOURS_PER_DAY):
		_state.clock.advance(GameClock.MINUTES_PER_HOUR)
		_farming_upkeep.pass_hour(hour)
	_farming_upkeep.end_day()
	NightUpkeep.new(_world, _weather, func() -> Array: return []).pass_night()


func _farming(key: String) -> float:
	return CropRules.default_rules().farming(key)


func test_tilled_soil_starts_at_the_default_moisture() -> void:
	assert_eq(_world.moisture_at(_tile), _farming("default_moisture"))


func test_setting_the_moisture_keeps_it_between_none_and_full() -> void:
	_world.set_moisture(_tile, 1.5)
	assert_eq(_world.moisture_at(_tile), 1.0)
	_world.set_moisture(_tile, -1.0)
	assert_eq(_world.moisture_at(_tile), 0.0)


func test_setting_the_moisture_emits_a_signal() -> void:
	watch_signals(_world)
	_world.set_moisture(_tile, 0.5)
	assert_signal_emitted_with_parameters(_world, "soil_moisture_changed", [_tile])


func test_the_watering_can_fills_dry_soil_and_costs_the_water_energy() -> void:
	_hold(ItemTypes.WATERING_CAN)
	_state.player.energy = 50.0
	_state.cheats.is_weight_off = true
	assert_eq(_state.use_at(_tile), ToolUse.Use.WATER)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.WATER)
	assert_eq(_world.moisture_at(_tile), 1.0)
	assert_almost_eq(_state.player.energy, 50.0 - _state.energy_rules.cost_of(&"water"), 0.0001)
	assert_eq(_state.use_at(_tile), ToolUse.Use.NOTHING, "nothing more to fill")


func test_the_watering_can_waters_a_planted_tile() -> void:
	_place(WorldObjectTypes.TURNIP)
	_hold(ItemTypes.WATERING_CAN)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.WATER)
	assert_eq(_world.moisture_at(_tile), 1.0)


func test_the_watering_can_does_nothing_on_grass() -> void:
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	_hold(ItemTypes.WATERING_CAN)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)


func test_a_dry_day_dries_the_soil_by_its_temperature_sun_and_wind() -> void:
	_weather.day.mean_temperature = 20.0
	_weather.day.sunlight_hours = 10.0
	_weather.day.max_wind_speed = 6.0
	_world.set_moisture(_tile, 1.0)
	_pass_night()
	var drying := (
		_farming("drying_base")
		+ _farming("drying_per_degree") * 20.0
		+ _farming("drying_per_sun_hour") * 10.0
		+ _farming("drying_per_wind") * 6.0
	)
	assert_almost_eq(_world.moisture_at(_tile), 1.0 - drying, 0.0001)


func test_a_hot_sunny_windy_day_dries_more_than_a_cold_dull_calm_one() -> void:
	_weather.day.mean_temperature = 3.0
	_weather.day.sunlight_hours = 1.0
	_world.set_moisture(_tile, 1.0)
	_pass_night()
	var after_cold := _world.moisture_at(_tile)
	_weather.day.mean_temperature = 22.0
	_weather.day.sunlight_hours = 10.0
	_weather.day.max_wind_speed = 8.0
	_world.set_moisture(_tile, 1.0)
	_pass_night()
	assert_lt(_world.moisture_at(_tile), after_cold)


func test_rain_wets_the_soil_and_a_rainy_hour_does_not_dry_it() -> void:
	_weather.day.rain_hours = 4.0
	_weather.day.sunlight_hours = 6.0
	_world.set_moisture(_tile, 0.2)
	_pass_night()
	assert_almost_eq(_world.moisture_at(_tile), 0.2 + _farming("rain_wets") * 4.0, 0.0001)


## The user, 2026-11-11 (task 175): the soil didn't seem to get wet in the rain.
func test_two_hours_of_heavy_rain_soak_fresh_soil_to_the_wettest_look() -> void:
	_weather.day.rain_hours = 24.0
	_farming_upkeep = FarmingUpkeep.new(_world, _weather)
	var first_hour := (_state.clock.day - 1) * CropLife.HOURS_PER_DAY
	for hour in range(first_hour, first_hour + 2):
		_state.clock.advance(GameClock.MINUTES_PER_HOUR)
		_farming_upkeep.pass_hour(hour)
	assert_eq(SoilWetness.look_for(_world.moisture_at(_tile)), SoilWetness.LOOKS - 1)


func test_a_long_rain_soaks_the_soil_but_not_beyond_full() -> void:
	_weather.day.rain_hours = 24.0
	_pass_night()
	assert_eq(_world.moisture_at(_tile), 1.0)


func test_the_soil_never_gets_drier_than_none() -> void:
	_weather.day.mean_temperature = 25.0
	_weather.day.sunlight_hours = 12.0
	_world.set_moisture(_tile, 0.05)
	_pass_night()
	assert_eq(_world.moisture_at(_tile), 0.0)


func test_every_tilled_tile_changes_overnight_loaded_or_not() -> void:
	var far := Vector2i(900, 900)
	_world.set_terrain(_tile + Vector2i(2, 0), Tile.Terrain.SOIL)
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Chunk.world_to_chunk(far)))
	_world.set_terrain(far, Tile.Terrain.SOIL)
	_world.remove_chunk(Chunk.world_to_chunk(far))
	_weather.day.rain_hours = 8.0
	_world.set_moisture(far, 0.1)
	_pass_night()
	assert_gt(_world.moisture_at(far), 0.1, "the tile of an unloaded chunk")
	assert_gt(_world.moisture_at(_tile + Vector2i(2, 0)), _farming("default_moisture"))


func test_the_nightly_pass_is_seen_by_the_crop_on_the_soil() -> void:
	_weather.day.mean_temperature = 14.0
	_weather.day.min_temperature = 8.0
	_weather.day.sunlight_hours = 6.0
	var crop := _place(WorldObjectTypes.TURNIP)
	_world.set_moisture(_tile, 1.0)
	_pass_night()
	assert_gt(CropLife.growth(crop), 0.0)
	# Without water the same weather is a drought for it.
	var thirsty := WorldObject.new(WorldObjectTypes.TURNIP, _tile + Vector2i(2, 0))
	_world.set_terrain(thirsty.pos, Tile.Terrain.SOIL)
	_world.add_object(thirsty)
	_world.set_moisture(thirsty.pos, 0.0)
	_pass_night()
	assert_gt(CropLife.damage(thirsty), 0.0)


func test_moisture_survives_a_save_and_a_chunk_reload() -> void:
	_world.set_moisture(_tile, 0.77)
	_reload_chunk()
	assert_eq(_world.moisture_at(_tile), 0.77)
	var restored := _through_save()
	assert_almost_eq(restored.world.moisture_at(_tile), 0.77, 0.0001)


func test_the_wetness_layer_follows_the_moisture_of_tilled_soil() -> void:
	var layer := SoilWetness.new()
	add_child_autofree(layer)
	layer.show_world(_world)
	var alone := SoilWetness._columns[0]
	_world.set_moisture(_tile, 0.0)
	assert_eq(layer.get_cell_source_id(_tile), -1, "the driest soil is the terrain's own look")
	_world.set_moisture(_tile, 0.5)
	assert_eq(layer.get_cell_atlas_coords(_tile), Vector2i(alone, 1))
	_world.set_moisture(_tile, 1.0)
	assert_eq(layer.get_cell_atlas_coords(_tile), Vector2i(alone, SoilWetness.LOOKS - 2))
	_world.set_moisture(_tile, 0.0)
	assert_eq(layer.get_cell_source_id(_tile), -1)


func test_the_wetness_layer_cuts_a_tile_to_the_bed_around_it() -> void:
	var layer := SoilWetness.new()
	add_child_autofree(layer)
	layer.show_world(_world)
	_world.set_moisture(_tile, 1.0)
	var alone := layer.get_cell_atlas_coords(_tile).x
	_world.set_terrain(_tile + Vector2i.RIGHT, Tile.Terrain.SOIL)
	assert_ne(layer.get_cell_atlas_coords(_tile).x, alone, "a tilled neighbour changes the shape")
	_world.set_terrain(_tile + Vector2i.RIGHT, Tile.Terrain.GRASS)
	assert_eq(layer.get_cell_atlas_coords(_tile).x, alone)


func test_the_wetness_layer_draws_soil_that_is_wet_already() -> void:
	_world.set_moisture(_tile, 0.9)
	var layer := SoilWetness.new()
	add_child_autofree(layer)
	layer.show_world(_world)
	assert_eq(layer.get_cell_atlas_coords(_tile).y, SoilWetness.LOOKS - 2)


func test_the_wetness_layer_counts_the_moist_tiles_beyond_loaded_chunks() -> void:
	var far := _tile + Vector2i(Chunk.CHUNK_SIZE * 20, 0)
	var layer := SoilWetness.new()
	add_child_autofree(layer)
	layer.show_world(_world)
	_world.set_moisture(_tile, 0.0)
	assert_eq(layer.mark_count(), 0)
	_world.set_moisture(_tile, 0.9)
	assert_eq(layer.mark_count(), 1)
	_world._edit_terrain(far, Tile.Terrain.SOIL)
	_world.set_moisture(far, 0.5)
	assert_eq(layer.mark_count(), 2, "a tilled tile of an unloaded chunk is drawn too")
	_world.set_moisture(_tile, 0.0)
	assert_eq(layer.mark_count(), 1)
