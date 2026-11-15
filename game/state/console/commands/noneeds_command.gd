extends ConsoleCommand


func name() -> String:
	return "noneeds"


func usage() -> String:
	return "noneeds"


func help() -> String:
	return "Toggle: the farm animals' hunger and thirst do not rise."


func run(_arguments: PackedStringArray) -> Array[String]:
	var cheats := context.state.cheats
	cheats.are_needs_off = not cheats.are_needs_off
	return [ConsoleHelper.toggle_message("No needs", cheats.are_needs_off)]
