extends ConsoleCommand


func name() -> String:
	return "nolate"


func usage() -> String:
	return "nolate"


func help() -> String:
	return "Toggle: staying up past 01:00 passes no one out and shows no warning."


func run(_arguments: PackedStringArray) -> Array[String]:
	var cheats := context.state.cheats
	cheats.is_late_off = not cheats.is_late_off
	return [ConsoleHelper.toggle_message("No late", cheats.is_late_off)]
