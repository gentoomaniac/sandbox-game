class_name Console
extends RefCounted
## The console's commands, run against a GameState: `run` takes a typed line and returns the
## lines to show. Plain logic; ConsoleView is the screen.

## Command name to its usage and what it does, in the order `help` lists them.
const COMMANDS := {
	"help": ["help [command]", "List the commands, or show what one takes."],
}
## The kind of each argument a command takes, in order, for Tab completion (see candidates).
## Numbers have no candidates; commands not listed take no arguments. `help <command>` and a
## missing or unknown name list the candidates of the kinds in ConsoleHelper.LISTED_KINDS.
const ARGUMENTS := {
	"help": [&"command"],
}
## The commands that take an animal kind, or `npc` and the id of a villager written by hand (see
## VillagerRules): `spawn` puts them in the world and `killall` takes them out.
const KIND_COMMANDS: Array[String] = ["spawn", "killall"]

## What the commands work on, and the hooks the game scene sets (see ConsoleContext).
var context: ConsoleContext

var _state: GameState
## The loaded commands by name.
var _commands := {}


func _init(state: GameState) -> void:
	_state = state
	context = ConsoleContext.new(state)
	var problems: Array[String] = []
	context.commands = ConsoleLoader.load_commands(ConsoleLoader.script_paths(), context, problems)
	for problem in problems:
		push_error("Console command: %s" % problem)
	for command in context.commands:
		_commands[command.name()] = command


## Runs a line such as "give logs 5" (a leading "/" is optional) and returns the output.
func run(line: String) -> Array[String]:
	var words := _words(line)
	if words.is_empty():
		return []
	var arguments := words.slice(1)
	if _commands.has(words[0]):
		return _commands[words[0]].run(arguments)
	var cheats := _state.cheats
	var output: Array[String]
	match words[0]:
		"help":
			output = _help(arguments)
		_:
			output = ["Unknown command: %s (try help)" % words[0]]
	return output


## The line with its last word completed: a command name, or an argument from ARGUMENTS. A
## word with several candidates goes as far as they agree; one with none leaves the line alone.
func complete(line: String) -> String:
	var words := _words(line)
	var is_new_word := line.ends_with(" ")
	var word_index := words.size() if is_new_word else maxi(words.size() - 1, 0)
	var typed := "" if is_new_word or words.is_empty() else words[-1]
	var command: ConsoleCommand = _commands.get(words[0]) if not words.is_empty() else null
	var kind := &"command"  # Past the last argument the kind stays empty: nothing to offer.
	if word_index > 0:
		var kinds: Array = ARGUMENTS.get(words[0], [])
		if command != null:
			kinds = command.argument_kinds_for(words.slice(1))
		elif words[0] in KIND_COMMANDS and words.size() > 1 and words[1] == ConsoleHelper.NPC:
			kinds = ConsoleHelper.NPC_ARGUMENTS
		kind = kinds[word_index - 1] if word_index <= kinds.size() else &""
	var offered := candidates(kind)
	var takes_villager_ids := words[0] in KIND_COMMANDS if not words.is_empty() else false
	if command != null:
		takes_villager_ids = command.takes_villager_ids()
	if word_index == 1 and takes_villager_ids:
		offered.append_array(candidates(&"villager"))  # `spawn antje` as well as `spawn npc antje`
	offered = offered.filter(func(name: String) -> bool: return name.begins_with(typed))
	if offered.is_empty():
		return line
	var completed := (
		offered[0] + " " if offered.size() == 1 else ConsoleHelper.common_prefix(offered)
	)
	return line.substr(0, line.length() - typed.length()) + completed


## What Tab offers for an argument of this kind (see ARGUMENTS).
func candidates(kind: StringName) -> Array[String]:
	var values := ConsoleHelper.candidates(kind, context)
	if kind == &"command":
		values.append_array(COMMANDS.keys())
	return values


## The answer to a name that is not a kind (`what` is "villager" or "track"): it and the names that
## the command takes.
func _unknown(what: String, word: String, command: String) -> Array[String]:
	var lines: Array[String] = ["Unknown %s: %s" % [what, word]]
	lines.append_array(_candidates_text(command))
	return lines


func _words(line: String) -> PackedStringArray:
	return line.strip_edges().trim_prefix("/").to_lower().split(" ", false)


func _help(arguments: PackedStringArray) -> Array[String]:
	var lines: Array[String] = []
	if arguments.size() > 1:
		return ["Usage: %s" % COMMANDS["help"][0]]
	if arguments.size() == 1:
		if _commands.has(arguments[0]):
			var command: ConsoleCommand = _commands[arguments[0]]
			lines.append("%s: %s" % [command.usage(), command.help()])
			lines.append_array(ConsoleHelper.candidates_text(command, context))
			return lines
		if not COMMANDS.has(arguments[0]):
			return ["Unknown command: %s (try help)" % arguments[0]]
		var entry: Array = COMMANDS[arguments[0]]
		lines.append("%s: %s" % [entry[0], entry[1]])
		lines.append_array(_candidates_text(arguments[0]))
		return lines
	for entry: Array in COMMANDS.values():
		lines.append("%s: %s" % [entry[0], entry[1]])
	for command in context.commands:
		lines.append("%s: %s" % [command.usage(), command.help()])
	return lines


## The names the command takes, from the same candidates Tab completes (see ConsoleHelper).
func _candidates_text(command: String) -> Array[String]:
	if _commands.has(command):
		return ConsoleHelper.candidates_text(_commands[command], context)
	var lines: Array[String] = []
	var kinds: Array = ARGUMENTS.get(command, [])
	if command in KIND_COMMANDS:
		kinds = kinds + [&"villager"]
	for kind: StringName in kinds:
		if ConsoleHelper.LISTED_KINDS.has(kind):
			lines.append_array(ConsoleHelper.candidates_lines(kind, context))
	return lines
