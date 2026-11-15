extends ConsoleCommand


func name() -> String:
	return "home"


func usage() -> String:
	return "home <villager> [here|none]"


func help() -> String:
	return (
		"Show where a villager lives, give them the house you are inside or at the door of"
		+ " (here), or free them of theirs (none). A house holds one household: a couple and"
		+ " their children, as many as the house has residents."
	)


func argument_kinds() -> Array[StringName]:
	return [&"villager", &"place"]


func run(arguments: PackedStringArray) -> Array[String]:
	var is_usage_wrong := arguments.is_empty() or arguments.size() > 2
	if arguments.size() == 2 and arguments[1] not in ConsoleHelper.PLACE_WORDS:
		is_usage_wrong = true
	if is_usage_wrong:
		return wrong_usage()
	var npc := ConsoleHelper.npc_named(arguments[0], context)
	if npc == null:
		return ConsoleHelper.unknown("villager", arguments[0], self, context)
	var where := arguments[1] if arguments.size() == 2 else ""
	return HomePlaces.new(context.state).home(npc, where)
