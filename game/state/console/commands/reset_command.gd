extends ConsoleCommand


func name() -> String:
	return "reset"


func usage() -> String:
	return "reset"


func help() -> String:
	return "Put you in your bed, the one you wake in (inside or out)."


func run(_arguments: PackedStringArray) -> Array[String]:
	PlayerRest.go_to_home_bed(context.state)
	return ["Back in bed"]
