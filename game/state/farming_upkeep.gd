class_name FarmingUpkeep
extends SimulationSystem
## What every hour does to the crops, in unloaded chunks too: they live through the hour (see
## CropLife), one 24th of a day, in the weather of its day and on soil with the moisture of the
## hour, and the end of a day counts for them (see `CropLife.end_day`). It also tells the soil what
## the weather does to its moisture (see `moisture_change`), which the soil catches up with when
## asked (see SoilMoisture). A whole day gives what the nightly pass used to.

var _world: World
var _weather: Weather


func _init(world: World, weather: Weather) -> void:
	_world = world
	_weather = weather
	_world.soil.hourly_change = moisture_change


func advance(_minutes: int, clock: GameClock) -> void:
	if not is_hour_end(clock):
		return
	var ended_hour_start := clock.total_minutes() - GameClock.MINUTES_PER_HOUR
	pass_hour(ended_hour_start / GameClock.MINUTES_PER_HOUR)
	if is_day_end(clock):
		end_day()


## Lets the hour `hour` (counted from the start of day 1) pass over the crops.
func pass_hour(hour: int) -> void:
	var day := hour / CropLife.HOURS_PER_DAY + 1
	for crop in _world.crops():
		var weather_day := _weather.day_summary(crop.pos, day)
		if CropLife.live_through_hour(crop, weather_day, _world.moisture_at(crop.pos)):
			_world.change_object(crop)


func skipped(_minutes: int, _clock: GameClock) -> void:
	_world.soil.prepare()


## The soil is brought up to now as well, which the next save would otherwise do in one go.
func skipped_over_frames(minutes: int, clock: GameClock, next_frame: Callable) -> void:
	skipped(minutes, clock)
	await _world.soil.catch_up_all_over_frames(next_frame)


## Counts the day that ended for every crop.
func end_day() -> void:
	for crop in _world.crops():
		if CropLife.end_day(crop):
			_world.change_object(crop)


## How much the moisture of the soil at a tile changes in the hour `hour` (counted from the start
## of day 1): the rain of the hour wets it, and a 24th of what the weather of the day dries.
func moisture_change(pos: Vector2i, hour: int) -> float:
	var rules := CropRules.default_rules()
	var day := hour / CropLife.HOURS_PER_DAY + 1
	var weather_day := _weather.day_summary(pos, day)
	var drying := (
		rules.farming("drying_base")
		+ rules.farming("drying_per_degree") * maxf(weather_day.mean_temperature, 0.0)
		+ rules.farming("drying_per_sun_hour") * weather_day.sunlight_hours
		+ rules.farming("drying_per_wind") * weather_day.max_wind_speed
	)
	var rain := _weather.rain_in_hour(pos, day, hour % CropLife.HOURS_PER_DAY)
	return rules.farming("rain_wets") * rain - drying / CropLife.HOURS_PER_DAY
