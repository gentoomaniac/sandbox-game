extends ConsoleCommand

## Minutes per unit of the command, and the longest skip (a year).
const UNITS := {"m": 1, "h": GameClock.MINUTES_PER_HOUR, "d": GameClock.MINUTES_PER_DAY}
const MAX_MINUTES := GameClock.DAYS_PER_YEAR * GameClock.MINUTES_PER_DAY


func name() -> String:
	return "skip"


func usage() -> String:
	return "skip <n>m|h|d"


func help() -> String:
	return "Let time pass: minutes, hours or days (crops grow, the weather moves on)."


func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() != 1 or arguments[0].length() < 2:
		return wrong_usage()
	var amount := arguments[0].left(-1)
	var unit := arguments[0].right(1)
	if not UNITS.has(unit) or not amount.is_valid_int() or int(amount) <= 0:
		return wrong_usage()
	var minutes: int = int(amount) * UNITS[unit]
	if minutes > MAX_MINUTES:
		return ["At most a year (%dd) at once" % GameClock.DAYS_PER_YEAR]
	context.state.simulation.skip(minutes)
	var clock := context.state.clock
	return ["Skipped to %s, %s" % [clock.date_text(), clock.time_text()]]
