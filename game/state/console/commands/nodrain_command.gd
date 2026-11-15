extends ConsoleCommand


func name() -> String:
	return "nodrain"


func usage() -> String:
	return "nodrain"


func help() -> String:
	return "Toggle: actions cost no energy."


func run(_arguments: PackedStringArray) -> Array[String]:
	var cheats := context.state.cheats
	cheats.is_drain_off = not cheats.is_drain_off
	return [ConsoleHelper.toggle_message("No drain", cheats.is_drain_off)]
