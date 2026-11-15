extends ConsoleCommand


func name() -> String:
	return "village"


func usage() -> String:
	return "village"


func help() -> String:
	return "Say where the village Wehlsbüll lies, and what it holds."


func run(_arguments: PackedStringArray) -> Array[String]:
	var village := context.state.world.village
	if village == null:
		return ["This world has no village"]
	return village.describe_from(context.state.player.tile())
