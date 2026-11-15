extends ConsoleCommand


func name() -> String:
	return "god"


func usage() -> String:
	return "god"


func help() -> String:
	return "Toggle invincibility: health never drops (energy still runs out)."


func run(_arguments: PackedStringArray) -> Array[String]:
	var cheats := context.state.cheats
	cheats.is_god = not cheats.is_god
	return [ConsoleHelper.toggle_message("God mode", cheats.is_god)]
