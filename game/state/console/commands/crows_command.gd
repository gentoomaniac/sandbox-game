extends ConsoleCommand


func name() -> String:
	return "crows"


func usage() -> String:
	return "crows [raid]"


func help() -> String:
	return (
		"Show the crow flocks, what the crows ate today and the scarecrows with the crops they guard;"
		+ " raid lets every flock raid the crops near it now, whoever is by, and eat from each one it"
		+ " tries."
	)


## `crows` shows the flocks and the day's tally; `crows raid` lets every flock raid at once.
func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() > 1 or (arguments.size() == 1 and arguments[0] != "raid"):
		return wrong_usage()
	var state := context.state
	if arguments.size() == 1:
		state.crop_raids.raid_hour(state.clock.total_minutes() / GameClock.MINUTES_PER_HOUR, true)
	var lines := state.crop_raids.describe()
	lines.append_array(state.scarecrows.describe())
	return lines
