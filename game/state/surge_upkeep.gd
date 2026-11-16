class_name SurgeUpkeep
extends SimulationSystem
## Rolls the storm surge ahead of each high water, `warning_hours` before it, lets the sea rise
## over the dykes when the time comes and follows the flood it leaves (see SurgeRoll, SurgeEvent
## and FloodState). The frames of play do the fill and the drain a little at a time (FloodState
## `step`); a skip of time makes up for them at once.

var _world: World
var _event: SurgeEvent
var _flood: FloodState
var _weather: Weather
var _roll: SurgeRoll
var _rules: WeatherRules
## A skip of time is under way: the fill and the drain finish at once, as no frame will do them.
var _is_skipping := false


func _init(world: World, weather: Weather, rules := WeatherRules.default_rules()) -> void:
	_world = world
	_event = world.surge
	_flood = world.flood
	_weather = weather
	_roll = SurgeRoll.new(world.world_seed, weather, rules)
	_rules = rules


func skip_begins(_minutes: int) -> void:
	_is_skipping = true


func skipped(_minutes: int, _clock: GameClock) -> void:
	_is_skipping = false
	_flood.settle(_world)


func advance(_minutes: int, clock: GameClock) -> void:
	var now := clock.total_minutes()
	if _event.is_holding_at(now) and not _flood.is_active():
		_flood.begin(_world, _event.level, now, SurgeRoll.tide_number_at(_event.peak_minute))
		_settle_if_skipping()
	var was_draining := _flood.phase == FloodState.Phase.DRAINING
	_flood.advance(_world, now, _event.is_holding_at(now))
	if not was_draining and _flood.phase == FloodState.Phase.DRAINING:
		_settle_if_skipping()
	if is_hour_end(clock):
		_flood.mend(_world, now)
		_drown_crops()
		_roll_ahead(now)
		if _event.is_stormy_at(now):
			_event.bell_rung.emit(_event.is_holding_at(now) and _flood.is_active())
	if is_day_end(clock):
		var rain_hours := _weather.day_summary(Vector2i.ZERO, clock.day - 1).rain_hours
		_flood.end_day(rain_hours)


func _settle_if_skipping() -> void:
	if _is_skipping:
		_flood.settle(_world)


# The crops under water suffer an hour of it.
func _drown_crops() -> void:
	if _flood.wet_count() == 0:
		return
	for crop in _world.crops():
		if CropLife.live_through_flood_hour(crop, _flood.depth_at(crop.pos)):
			_world.change_object(crop)


# Rolls the next high water when it is `warning_hours` away or less, once.
func _roll_ahead(now: int) -> void:
	if _event.has_surge() and now > _event.end_minute():
		_event.clear()
	var next_tide := ceili(now / Tide.PERIOD_MINUTES)
	var warning_minutes := _rules.value("surge", "warning_hours") * GameClock.MINUTES_PER_HOUR
	if next_tide <= _event.last_rolled_tide:
		return
	if SurgeRoll.peak_minute(next_tide) - now > warning_minutes:
		return
	_event.last_rolled_tide = next_tide
	var level := _roll.level_for(next_tide)
	if level > 0.0:
		var hold_minutes := int(_rules.value("surge", "hold_hours") * GameClock.MINUTES_PER_HOUR)
		_event.expect(level, SurgeRoll.peak_minute(next_tide), hold_minutes)
