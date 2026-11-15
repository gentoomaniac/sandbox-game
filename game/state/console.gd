class_name Console
extends RefCounted
## The console's commands, run against a GameState: `run` takes a typed line and returns the
## lines to show. Plain logic; ConsoleView is the screen.

## What the commands work on, and the hooks the game scene sets (see ConsoleContext).
var context: ConsoleContext


func _init(state: GameState) -> void:
	context = ConsoleContext.new(state)
	var problems: Array[String] = []
	context.commands = ConsoleLoader.load_commands(ConsoleLoader.script_paths(), context, problems)
	for problem in problems:
		push_error("Console command: %s" % problem)


func _notification(what: int) -> void:
	# The context holds the commands (for `help`) and each command holds the context: a cycle that
	# reference counting never frees. The console owns both, so it breaks the cycle as it goes.
	if what == NOTIFICATION_PREDELETE:
		context.commands.clear()


## Runs a line such as "give logs 5" (a leading "/" is optional) and returns the output.
func run(line: String) -> Array[String]:
	var words := _words(line)
	if words.is_empty():
		return []
	var command := context.command_named(words[0])
	if command == null:
		return ["Unknown command: %s (try help)" % words[0]]
	return command.run(words.slice(1))


## The line with its last word completed: a command name, or an argument of the kind the command
## says. A word with several candidates goes as far as they agree; one with none leaves the line
## alone.
func complete(line: String) -> String:
	var words := _words(line)
	var is_new_word := line.ends_with(" ")
	var word_index := words.size() if is_new_word else maxi(words.size() - 1, 0)
	var typed := "" if is_new_word or words.is_empty() else words[-1]
	var command := context.command_named(words[0]) if not words.is_empty() else null
	var kind := &"command"  # Past the last argument the kind stays empty: nothing to offer.
	if word_index > 0:
		var kinds: Array[StringName] = []
		if command != null:
			kinds = command.argument_kinds_for(words.slice(1))
		kind = kinds[word_index - 1] if word_index <= kinds.size() else &""
	var offered := candidates(kind)
	if word_index == 1 and command != null and command.takes_villager_ids():
		offered.append_array(candidates(&"villager"))  # `spawn antje` as well as `spawn npc antje`
	offered = offered.filter(func(name: String) -> bool: return name.begins_with(typed))
	if offered.is_empty():
		return line
	var completed := (
		offered[0] + " " if offered.size() == 1 else ConsoleHelper.common_prefix(offered)
	)
	return line.substr(0, line.length() - typed.length()) + completed


## What Tab offers for an argument of this kind (see ConsoleCommand.argument_kinds).
func candidates(kind: StringName) -> Array[String]:
	return ConsoleHelper.candidates(kind, context)


func _words(line: String) -> PackedStringArray:
	return line.strip_edges().trim_prefix("/").to_lower().split(" ", false)
