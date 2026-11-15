extends ConsoleCommand


func name() -> String:
	return "noweight"


func usage() -> String:
	return "noweight"


func help() -> String:
	return "Toggle: carried weight doesn't raise costs."


func run(_arguments: PackedStringArray) -> Array[String]:
	var cheats := context.state.cheats
	cheats.is_weight_off = not cheats.is_weight_off
	return [ConsoleHelper.toggle_message("No weight", cheats.is_weight_off)]
