extends ConsoleCommand


func name() -> String:
	return "snow"


func usage() -> String:
	return "snow [0..1|auto]"


func help() -> String:
	return "Show the snow cover, force it (0 to 1) or return to the weather (auto)."


func argument_kinds() -> Array[StringName]:
	return [&"snow"]


func run(arguments: PackedStringArray) -> Array[String]:
	var state := context.state
	var snow := state.snow_cover
	if arguments.size() > 1:
		return wrong_usage()
	if arguments.size() == 1:
		if arguments[0] == "auto":
			snow.forced = -1.0
			return ["Snow cover follows the weather"]
		if (
			not arguments[0].is_valid_float()
			or float(arguments[0]) < 0.0
			or float(arguments[0]) > 1.0
		):
			return wrong_usage()
		snow.forced = float(arguments[0])
		return ["Snow cover forced to %s (snow auto ends it)" % arguments[0]]
	var lines: Array[String] = [
		(
			"Snow cover %d %%, frost %d %%"
			% [roundi(state.current_snow_cover() * 100.0), roundi(state.current_frost() * 100.0)]
		)
	]
	if snow.forced >= 0.0:
		lines.append("Forced: %s" % snow.forced)
	return lines
