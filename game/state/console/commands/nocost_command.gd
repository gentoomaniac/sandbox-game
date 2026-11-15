extends ConsoleCommand


func name() -> String:
	return "nocost"


func usage() -> String:
	return "nocost"


func help() -> String:
	return "Toggle: buildings and crafting need no materials."


func run(_arguments: PackedStringArray) -> Array[String]:
	var cheats := context.state.cheats
	cheats.is_cost_off = not cheats.is_cost_off
	return [ConsoleHelper.toggle_message("No cost", cheats.is_cost_off)]
