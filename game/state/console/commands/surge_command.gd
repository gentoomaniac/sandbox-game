extends ConsoleCommand
## `surge`: shows, starts or ends the storm surge (see SurgeEvent).

## The level of a surge the console starts without one given, in metres: a strong storm's.
const DEFAULT_LEVEL := 2.8


func name() -> String:
	return "surge"


func usage() -> String:
	return "surge [metres|off]"


func help() -> String:
	return (
		"Show the storm surge, start one that rises now (default %.1f m) or end it." % DEFAULT_LEVEL
	)


func run(arguments: PackedStringArray) -> Array[String]:
	var state := context.state
	var surge := state.world.surge
	var now := state.clock.total_minutes()
	if arguments.size() > 1:
		return wrong_usage()
	if arguments.size() == 1:
		if arguments[0] == "off":
			surge.clear()
			return ["No surge"]
		if not arguments[0].is_valid_float() or float(arguments[0]) <= 0.0:
			return wrong_usage()
		surge.start_now(float(arguments[0]), now, _hold_minutes())
		return ["A surge of %s m starts now" % arguments[0]]
	if not surge.has_surge():
		return ["No surge expected"]
	var when := (
		"the sea rises at %s" if surge.is_expected_at(now) else "the sea stands high until %s"
	)
	var minute := surge.start_minute() if surge.is_expected_at(now) else surge.end_minute()
	return [
		(
			"A surge of %.1f m: %s"
			% [surge.level, when % Sun.time_text(minute % GameClock.MINUTES_PER_DAY)]
		)
	]


func _hold_minutes() -> int:
	return int(
		WeatherRules.default_rules().value("surge", "hold_hours") * GameClock.MINUTES_PER_HOUR
	)
