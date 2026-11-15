extends ConsoleCommand


func name() -> String:
	return "help"


func usage() -> String:
	return "help [command]"


func help() -> String:
	return "List the commands, or show what one takes."


func argument_kinds() -> Array[StringName]:
	return [&"command"]


func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() > 1:
		return wrong_usage()
	var lines: Array[String] = []
	if arguments.is_empty():
		for command in context.commands:
			lines.append(_describe(command))
		return lines
	var command := context.command_named(arguments[0])
	if command == null:
		return ["Unknown command: %s (try help)" % arguments[0]]
	lines.append(_describe(command))
	lines.append_array(ConsoleHelper.candidates_text(command, context))
	return lines


func _describe(command: ConsoleCommand) -> String:
	return "%s: %s" % [command.usage(), command.help()]
