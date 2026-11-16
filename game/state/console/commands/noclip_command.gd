extends ConsoleCommand


func name() -> String:
	return "noclip"


func usage() -> String:
	return "noclip"


func help() -> String:
	return "Toggle: walk through anything (indoors within the room)."


func run(_arguments: PackedStringArray) -> Array[String]:
	var state := context.state
	state.cheats.is_noclip = not state.cheats.is_noclip
	var lines: Array[String] = [ConsoleHelper.toggle_message("No clip", state.cheats.is_noclip)]
	# Off inside a lake or a wall: onto the nearest ground they fit on.
	if not state.cheats.is_noclip and not state.travel.put_player_on_free_ground(state):
		lines.append("No free ground near you: walk out, or turn noclip on again")
	return lines
