extends ConsoleCommand


func name() -> String:
	return "replan"


func usage() -> String:
	return "replan <villager>"


func help() -> String:
	return "Have the model plan the rest of a villager's day now, ahead of the rest."


func argument_kinds() -> Array[StringName]:
	return [&"villager"]


func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() != 1:
		return wrong_usage()
	var npc := ConsoleHelper.npc_named(arguments[0], context)
	if npc == null:
		return ConsoleHelper.unknown("villager", arguments[0], self, context)
	var replanner := context.replanner
	return [replanner.call(npc) if replanner.is_valid() else "No planner here"]
