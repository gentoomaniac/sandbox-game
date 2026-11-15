class_name Console
extends RefCounted
## The console's commands, run against a GameState: `run` takes a typed line and returns the
## lines to show. Plain logic; ConsoleView is the screen.

## Command name to its usage and what it does, in the order `help` lists them.
const COMMANDS := {
	"help": ["help [command]", "List the commands, or show what one takes."],
	"god": ["god", "Toggle invincibility: health never drops (energy still runs out)."],
	"nodrain": ["nodrain", "Toggle: actions cost no energy."],
	"noweight": ["noweight", "Toggle: carried weight doesn't raise costs."],
	"nocost": ["nocost", "Toggle: buildings and crafting need no materials."],
	"nolate": ["nolate", "Toggle: staying up past 01:00 passes no one out and shows no warning."],
	"noneeds": ["noneeds", "Toggle: the farm animals' hunger and thirst do not rise."],
	"noclip": ["noclip", "Toggle: walk through anything (indoors within the room)."],
	"freeze": ["freeze", "Toggle: time stands still (you and the animals still move)."],
	"weather":
	[
		"weather [clear|cloudy|overcast|rain|snow|fog|wind|storm|thunder|auto]",
		"Show the weather, force a condition, or return to the simulation (auto).",
	],
	"snow":
	[
		"snow [0..1|auto]",
		"Show the snow cover, force it (0 to 1) or return to the weather (auto).",
	],
	"home":
	[
		"home <villager> [here|none]",
		(
			"Show where a villager lives, give them the house you are inside or at the door of"
			+ " (here), or free them of theirs (none). A house holds one household: a couple and"
			+ " their children, as many as the house has residents."
		),
	],
	"work":
	[
		"work <villager> [here|none]",
		(
			"Show where a villager works, send them to the building you are in or at, or to the"
			+ " spot you stand on where there is none (here), or free them of it (none)."
		),
	],
	"goto":
	[
		"goto <villager> <x>,<y>|here",
		(
			"Send a villager to a tile, or to where you stand (here): it finds its way, along lanes,"
			+ " round fences and through gates. On its way means a search is under way: that there is no"
			+ " way comes later, F4 shows its path and whether it is blocked."
		),
	],
	"routine":
	[
		"routine <villager> [day]",
		(
			"Say where a villager is going and why, what comes next and when they leave for it;"
			+ " with day, every entry of their day."
		),
	],
	"replan":
	[
		"replan <villager>",
		"Have the model plan the rest of a villager's day now, ahead of the rest."
	],
	"play":
	[
		"play <track>",
		"Play a piece of music in a loop (another one crossfades), rendered first; stop ends it.",
	],
	"stop": ["stop", "Fade the music out."],
}
## The kind of each argument a command takes, in order, for Tab completion (see candidates).
## Numbers have no candidates; commands not listed take no arguments. `help <command>` and a
## missing or unknown name list the candidates of the kinds in ConsoleHelper.LISTED_KINDS.
const ARGUMENTS := {
	"help": [&"command"],
	"weather": [&"weather"],
	"snow": [&"snow"],
	"home": [&"villager", &"place"],
	"work": [&"villager", &"place"],
	"goto": [&"villager", &"destination"],
	"routine": [&"villager", &"routine_view"],
	"replan": [&"villager"],
	"play": [&"track"],
}
## The commands that take an animal kind, or `npc` and the id of a villager written by hand (see
## VillagerRules): `spawn` puts them in the world and `killall` takes them out.
const KIND_COMMANDS: Array[String] = ["spawn", "killall"]

## What the commands work on, and the hooks the game scene sets (see ConsoleContext).
var context: ConsoleContext

var _state: GameState
var _home_commands: HomeCommands
## The loaded commands by name.
var _commands := {}


func _init(state: GameState) -> void:
	_state = state
	_home_commands = HomeCommands.new(state)
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
		"god":
			cheats.is_god = not cheats.is_god
			output = [ConsoleHelper.toggle_message("God mode", cheats.is_god)]
		"nodrain":
			cheats.is_drain_off = not cheats.is_drain_off
			output = [ConsoleHelper.toggle_message("No drain", cheats.is_drain_off)]
		"noweight":
			cheats.is_weight_off = not cheats.is_weight_off
			output = [ConsoleHelper.toggle_message("No weight", cheats.is_weight_off)]
		"nocost":
			cheats.is_cost_off = not cheats.is_cost_off
			output = [ConsoleHelper.toggle_message("No cost", cheats.is_cost_off)]
		"nolate":
			cheats.is_late_off = not cheats.is_late_off
			output = [ConsoleHelper.toggle_message("No late", cheats.is_late_off)]
		"noneeds":
			cheats.are_needs_off = not cheats.are_needs_off
			output = [ConsoleHelper.toggle_message("No needs", cheats.are_needs_off)]
		"noclip":
			cheats.is_noclip = not cheats.is_noclip
			output = [ConsoleHelper.toggle_message("No clip", cheats.is_noclip)]
			# Off inside a lake or a wall: onto the nearest ground they fit on.
			if not cheats.is_noclip and not _state.put_player_on_free_ground():
				output.append("No free ground near you: walk out, or turn noclip on again")
		"freeze":
			cheats.is_time_stopped = not cheats.is_time_stopped
			output = [ConsoleHelper.toggle_message("Time stopped", cheats.is_time_stopped)]
		"weather":
			output = _weather(arguments)
		"snow":
			output = _snow(arguments)
		"home", "work":
			output = _home_or_work(words[0], arguments)
		"goto":
			output = _goto(arguments)
		"routine", "replan":
			output = _routine_or_replan(words[0], arguments)
		"play":
			output = _play(arguments)
		"stop":
			if context.music_stopper.is_valid():
				context.music_stopper.call()
				output = ["Music fading out"]
			else:
				output = [ConsoleHelper.NO_MUSIC]
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


func _weather(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() > 1:
		return ["Usage: %s" % COMMANDS["weather"][0]]
	if arguments.size() == 1:
		var word := arguments[0]
		if word == "auto":
			_state.weather_override = &""
			_state.refresh_mud()
			return ["Weather follows the simulation"]
		if not Weather.FORCEABLE.has(StringName(word)):
			return ["Usage: %s" % COMMANDS["weather"][0]]
		_state.weather_override = StringName(word)
		_state.refresh_mud()
		return ["Weather forced to %s (weather auto ends it)" % word]
	var sample := _state.current_weather()
	var lines: Array[String] = [sample.values_text(), "Conditions: " + sample.conditions_text()]
	var day := _state.clock.day
	lines.append(
		(
			"Sun: %s to %s"
			% [Sun.time_text(_state.sun.sunrise(day)), Sun.time_text(_state.sun.sunset(day))]
		)
	)
	lines.append("Today: " + _state.weather.day_summary(_state.player.tile(), day).text())
	if _state.weather_override != &"":
		lines.append("Forced: %s" % _state.weather_override)
	return lines


func _snow(arguments: PackedStringArray) -> Array[String]:
	var snow := _state.snow_cover
	if arguments.size() > 1:
		return ["Usage: %s" % COMMANDS["snow"][0]]
	if arguments.size() == 1:
		if arguments[0] == "auto":
			snow.forced = -1.0
			return ["Snow cover follows the weather"]
		if (
			not arguments[0].is_valid_float()
			or float(arguments[0]) < 0.0
			or float(arguments[0]) > 1.0
		):
			return ["Usage: %s" % COMMANDS["snow"][0]]
		snow.forced = float(arguments[0])
		return ["Snow cover forced to %s (snow auto ends it)" % arguments[0]]
	var lines: Array[String] = [
		(
			"Snow cover %d %%, frost %d %%"
			% [roundi(_state.current_snow_cover() * 100.0), roundi(_state.current_frost() * 100.0)]
		)
	]
	if snow.forced >= 0.0:
		lines.append("Forced: %s" % snow.forced)
	return lines


## `home` or `work` (`command`): shows the house or workplace of a villager, or sets or frees it.
func _home_or_work(command: String, arguments: PackedStringArray) -> Array[String]:
	var is_usage_wrong := arguments.is_empty() or arguments.size() > 2
	if arguments.size() == 2 and arguments[1] not in ConsoleHelper.PLACE_WORDS:
		is_usage_wrong = true
	if is_usage_wrong:
		return ["Usage: %s" % COMMANDS[command][0]]
	var npc := ConsoleHelper.npc_named(arguments[0], context)
	if npc == null:
		return _unknown("villager", arguments[0], command)
	var where := arguments[1] if arguments.size() == 2 else ""
	if command == "home":
		return _home_commands.home(npc, where)
	return _home_commands.work(npc, where)


## `routine`: where a villager is going and why, or with `day` their whole day. `replan`: has the
## model plan the rest of their day.
func _routine_or_replan(command: String, arguments: PackedStringArray) -> Array[String]:
	var most_arguments := 2 if command == "routine" else 1
	var is_usage_wrong := arguments.is_empty() or arguments.size() > most_arguments
	if arguments.size() == 2 and arguments[1] != ConsoleHelper.WHOLE_DAY:
		is_usage_wrong = true
	if is_usage_wrong:
		return ["Usage: %s" % COMMANDS[command][0]]
	var npc := ConsoleHelper.npc_named(arguments[0], context)
	if npc == null:
		return _unknown("villager", arguments[0], command)
	if command == "replan":
		return [context.replanner.call(npc) if context.replanner.is_valid() else "No planner here"]
	return RoutineReport.lines(_state, npc, arguments.size() == 2)


## `goto`: sends a villager to a tile of the world, to watch the way they find.
func _goto(arguments: PackedStringArray) -> Array[String]:
	var usage: Array[String] = ["Usage: %s" % COMMANDS["goto"][0]]
	if arguments.size() != 2:
		return usage
	var npc := ConsoleHelper.npc_named(arguments[0], context)
	if npc == null:
		return _unknown("villager", arguments[0], "goto")
	var tile := _state.player.tile()
	if arguments[1] == ConsoleHelper.HERE:
		if _state.is_inside():
			return ["Go outside first: villagers walk in the world"]
	else:
		var numbers := arguments[1].split(",")
		if numbers.size() != 2 or not numbers[0].is_valid_int() or not numbers[1].is_valid_int():
			return usage
		tile = Vector2i(int(numbers[0]), int(numbers[1]))
	_state.npcs.walk_to(npc, tile, _state.world)
	return _goto_answer(npc, tile)


## What a villager who has just been sent to `tile` says: it is there, or a search is under way (F4
## says what comes of it).
func _goto_answer(npc: Npc, tile: Vector2i) -> Array[String]:
	if not npc.is_travelling():
		return ["%s is at %s already" % [npc.name, tile]]
	return ["%s is on its way to %s, %d tiles off" % [npc.name, tile, _tiles_between(npc, tile)]]


## The tiles in a straight line, to the nearest.
func _tiles_between(npc: Npc, tile: Vector2i) -> int:
	return roundi(npc.position.distance_to(Vector2(tile) + Vector2(0.5, 0.5)))


func _play(arguments: PackedStringArray) -> Array[String]:
	if not context.music_player.is_valid():
		return [ConsoleHelper.NO_MUSIC]
	if arguments.size() != 1:
		var lines: Array[String] = ["Usage: %s" % COMMANDS["play"][0]]
		lines.append_array(_candidates_text("play"))
		return lines
	var track := track_named(arguments[0], candidates(&"track"))
	if track.is_empty():
		return _unknown("track", arguments[0], "play")
	var line: String = context.music_player.call(track)
	return [line]


## The track `name` stands for among `tracks`: the whole name, or the name without its first word
## ("tide" for "sketch_tide"); "" when there is none, or more than one.
static func track_named(name: String, tracks: Array[String]) -> String:
	var matches := tracks.filter(
		func(track: String) -> bool: return name == track or track.ends_with("_" + name)
	)
	return matches[0] if matches.size() == 1 else ""
