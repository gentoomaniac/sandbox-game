extends ConsoleCommand


func name() -> String:
	return "routine"


func usage() -> String:
	return "routine <villager> [day]"


func help() -> String:
	return (
		"Say where a villager is going and why, what comes next and when they leave for it;"
		+ " with day, every entry of their day."
	)


func argument_kinds() -> Array[StringName]:
	return [&"villager", &"routine_view"]


func run(arguments: PackedStringArray) -> Array[String]:
	var is_usage_wrong := arguments.is_empty() or arguments.size() > 2
	if arguments.size() == 2 and arguments[1] != ConsoleHelper.WHOLE_DAY:
		is_usage_wrong = true
	if is_usage_wrong:
		return wrong_usage()
	var npc := ConsoleHelper.npc_named(arguments[0], context)
	if npc == null:
		return ConsoleHelper.unknown("villager", arguments[0], self, context)
	return RoutineReport.lines(context.state, npc, arguments.size() == 2)
