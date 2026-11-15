extends ConsoleCommand


func name() -> String:
	return "map"


func usage() -> String:
	return "map"


func help() -> String:
	return (
		"Open the world map, a test tool: all the land, under a fog where you have not been, with"
		+ " the villagers and you. Click a spot to teleport there. map again or Escape closes it."
	)


func run(arguments: PackedStringArray) -> Array[String]:
	if not arguments.is_empty():
		return wrong_usage()
	if not context.map_toggler.is_valid():
		return [ConsoleHelper.NO_MAP]
	var line: String = context.map_toggler.call()
	return [line]
