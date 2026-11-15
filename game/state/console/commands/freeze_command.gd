extends ConsoleCommand


func name() -> String:
	return "freeze"


func usage() -> String:
	return "freeze"


func help() -> String:
	return "Toggle: time stands still (you and the animals still move)."


func run(_arguments: PackedStringArray) -> Array[String]:
	var cheats := context.state.cheats
	cheats.is_time_stopped = not cheats.is_time_stopped
	return [ConsoleHelper.toggle_message("Time stopped", cheats.is_time_stopped)]
