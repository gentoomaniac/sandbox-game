class_name SurgeUpkeep
extends SimulationSystem
## Rolls the storm surge ahead of each high water, `warning_hours` before it, and ends it when the
## water has fallen (see SurgeRoll and SurgeEvent).

var _event: SurgeEvent
var _roll: SurgeRoll
var _rules: WeatherRules


func _init(event: SurgeEvent, roll: SurgeRoll, rules := WeatherRules.default_rules()) -> void:
	_event = event
	_roll = roll
	_rules = rules


func advance(_minutes: int, clock: GameClock) -> void:
	if not is_hour_end(clock):
		return
	var now := clock.total_minutes()
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
