extends ConsoleCommand


func name() -> String:
	return "weather"


func usage() -> String:
	return "weather [clear|cloudy|overcast|rain|snow|fog|wind|storm|thunder|auto]"


func help() -> String:
	return "Show the weather, force a condition, or return to the simulation (auto)."


func argument_kinds() -> Array[StringName]:
	return [&"weather"]


func run(arguments: PackedStringArray) -> Array[String]:
	var state := context.state
	if arguments.size() > 1:
		return wrong_usage()
	if arguments.size() == 1:
		var word := arguments[0]
		if word == "auto":
			state.weather_override = &""
			state.refresh_mud()
			return ["Weather follows the simulation"]
		if not Weather.FORCEABLE.has(StringName(word)):
			return wrong_usage()
		state.weather_override = StringName(word)
		state.refresh_mud()
		return ["Weather forced to %s (weather auto ends it)" % word]
	var sample := state.current_weather()
	var lines: Array[String] = [sample.values_text(), "Conditions: " + sample.conditions_text()]
	var day := state.clock.day
	lines.append(
		(
			"Sun: %s to %s"
			% [Sun.time_text(state.sun.sunrise(day)), Sun.time_text(state.sun.sunset(day))]
		)
	)
	lines.append("Today: " + state.weather.day_summary(state.player.tile(), day).text())
	if state.weather_override != &"":
		lines.append("Forced: %s" % state.weather_override)
	return lines
