class_name Console
extends RefCounted
## The console's commands, run against a GameState: `run` takes a typed line and returns the
## lines to show. Plain logic; ConsoleView is the screen.

## Command name to its usage and what it does, in the order `help` lists them.
const COMMANDS := {
	"help": ["help [command]", "List the commands, or show what one takes."],
	"tp": ["tp <x> <y>", "Teleport to a world tile; from inside a house you step out there."],
	"give": ["give <item> [count]", "Put items in the inventory."],
	"god": ["god", "Toggle invincibility: health never drops (energy still runs out)."],
	"nodrain": ["nodrain", "Toggle: actions cost no energy."],
	"noweight": ["noweight", "Toggle: carried weight doesn't raise costs."],
	"nocost": ["nocost", "Toggle: buildings and crafting need no materials."],
	"nolate": ["nolate", "Toggle: staying up past 01:00 passes no one out and shows no warning."],
	"noneeds": ["noneeds", "Toggle: the farm animals' hunger and thirst do not rise."],
	"noclip": ["noclip", "Toggle: walk through anything (indoors within the room)."],
	"freeze": ["freeze", "Toggle: time stands still (you and the animals still move)."],
	"spawn":
	[
		"spawn <kind> [count]",
		(
			"Put animals or villagers (npc, or the id of one written by hand, such as antje) near"
			+ " you; farm animals and villagers stay."
		),
	],
	"killall":
	[
		"killall <kind> | killall npc [<id>]",
		(
			"Remove every animal of a kind (the same kinds as spawn), or villagers (npc: those made"
			+ " up; npc <id>: one named), from the game and the save. Wild animals are not saved:"
			+ " others may come by the usual rules."
		),
	],
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
	"skip":
	[
		"skip <n>m|h|d",
		"Let time pass: minutes, hours or days (crops grow, the weather moves on).",
	],
	"crop":
	[
		"crop",
		"Show the growth, damage and needs of the crop in front of you or the nearest one.",
	],
	"skill": ["skill <skill> <points>", "Set a skill's points (0 to 100)."],
	"attribute":
	[
		"attribute <attribute> <level>",
		"Set an attribute's level (strength, agility, stamina or hp) and show what it gives.",
	],
	"friendship":
	[
		"friendship [0..100]",
		"Show the friendship of the animal nearest to you, or set it.",
	],
	"crows":
	[
		"crows [raid]",
		(
			"Show the crow flocks, what the crows ate today and the scarecrows with the crops they guard;"
			+ " raid lets every flock raid the crops near it now, whoever is by, and eat from each one it"
			+ " tries."
		),
	],
	"deeds": ["deeds", "List what you did within sight of villagers, and who saw it."],
	"village": ["village", "Say where the village Wehlsbüll lies, and what it holds."],
	"gossip":
	[
		"gossip <villager>",
		(
			"List the stories and the long-term memories a villager keeps, with their weights (the"
			+ " id of a villager written by hand, such as antje, or a first name)."
		),
	],
	"opinion":
	[
		"opinion <villager> [points]",
		(
			"Show what a villager thinks of you, or set it in points (-100 to 1000; below -20 is"
			+ " cold, from 20 warm)."
		),
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
	"tp": [&"number", &"number"],
	"give": [&"item", &"number"],
	"spawn": [&"animal", &"number"],
	"killall": [&"animal"],
	"weather": [&"weather"],
	"snow": [&"snow"],
	"skill": [&"skill", &"number"],
	"attribute": [&"attribute", &"number"],
	"gossip": [&"villager"],
	"opinion": [&"villager", &"number"],
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
## Minutes per unit of the `skip` command, and the longest skip (a year).
const SKIP_UNITS := {"m": 1, "h": GameClock.MINUTES_PER_HOUR, "d": GameClock.MINUTES_PER_DAY}
const MAX_SKIP_MINUTES := GameClock.DAYS_PER_YEAR * GameClock.MINUTES_PER_DAY
## How far (in tiles) the `friendship` command looks for an animal.
const FRIENDSHIP_SEARCH_RADIUS := 3.0

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
		"tp":
			output = _tp(arguments)
		"give":
			output = _give(arguments)
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
		"killall":
			output = _killall(arguments)
		"spawn":
			if arguments.is_empty():
				output = _candidates_text("spawn")
			elif (
				arguments.size() == 2
				and arguments[0] == ConsoleHelper.NPC
				and not arguments[1].is_valid_int()
			):
				output = _spawn_villager(arguments[1])
			elif arguments.size() == 1 and _state.npcs.villagers.has(arguments[0]):
				output = _spawn_villager(arguments[0])
			else:
				output = _spawn(arguments)
		"weather":
			output = _weather(arguments)
		"snow":
			output = _snow(arguments)
		"skip":
			output = _skip(arguments)
		"crop":
			output = CropCommands.crop(_state)
		"crows":
			output = _crows(arguments)
		"skill":
			output = _skill(arguments)
		"attribute":
			output = _attribute(arguments)
		"friendship":
			output = _friendship(arguments)
		"deeds":
			output = _deeds()
		"village":
			var village := _state.world.village
			output = (
				["This world has no village"] as Array[String]
				if village == null
				else village.describe_from(_state.player.tile())
			)
		"gossip":
			output = _gossip(arguments)
		"opinion":
			output = _opinion(arguments)
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


func _tp(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() != 2 or not arguments[0].is_valid_int() or not arguments[1].is_valid_int():
		return ["Usage: %s" % COMMANDS["tp"][0]]
	var tile := Vector2i(int(arguments[0]), int(arguments[1]))
	if not World.is_in_bounds(tile):
		return ["Tile %d, %d is outside the world" % [tile.x, tile.y]]
	if _state.world.building_at(tile) != null:
		return ["Tile %d, %d is covered by a building" % [tile.x, tile.y]]
	if not _is_walkable_even_if_unloaded(tile):
		return ["Can't walk on tile %d, %d" % [tile.x, tile.y]]
	_state.teleport_to(tile)
	return ["Teleported to %d, %d" % [tile.x, tile.y]]


## Whether a tile of the world is walkable, also when its chunk is not loaded: that chunk is
## generated for the look and dropped again, as the world view draws only the chunks it loads.
func _is_walkable_even_if_unloaded(tile: Vector2i) -> bool:
	var world := _state.world
	var coords := Chunk.world_to_chunk(tile)
	var was_loaded := world.is_chunk_loaded(coords)
	if not was_loaded:
		world.add_chunk(WorldGenerator.new(world.world_seed).generate_chunk(coords))
	var is_walkable := world.is_walkable(tile)
	if not was_loaded:
		world.remove_chunk(coords)
	return is_walkable


func _give(arguments: PackedStringArray) -> Array[String]:
	var is_count_valid := (
		arguments.size() < 2 or (arguments[1].is_valid_int() and int(arguments[1]) > 0)
	)
	if arguments.is_empty() or arguments.size() > 2 or not is_count_valid:
		return ["Usage: %s" % COMMANDS["give"][0]]
	var item := StringName(arguments[0])
	if not ItemTypes.TYPES.has(item):
		return ConsoleHelper.unknown_item(arguments[0])
	var count := 1 if arguments.size() < 2 else int(arguments[1])
	var left := _state.player.inventory.add(item, count)
	var lines: Array[String] = []
	if left < count:
		lines.append("Gave %d %s" % [count - left, ItemTypes.TYPES[item]["name"]])
	if left > 0:
		lines.append("Inventory full: %d not added" % left)
	return lines


func _skill(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() != 2 or not arguments[1].is_valid_float():
		return ["Usage: %s" % COMMANDS["skill"][0]]
	var skills := _state.player.skills
	var skill := StringName(arguments[0])
	if not skills.rules.has_skill(skill):
		return ["Unknown skill: %s" % arguments[0]]
	skills.set_points(skill, float(arguments[1]))
	return ["%s is %s" % [skills.rules.skill_name(skill), skills.points(skill)]]


func _attribute(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() != 2 or not arguments[1].is_valid_int():
		return ["Usage: %s" % COMMANDS["attribute"][0]]
	var attributes := _state.player.attributes
	var attribute := StringName(arguments[0])
	if not attributes.rules.has_attribute(attribute):
		return ["Unknown attribute: %s" % arguments[0]]
	attributes.set_level(attribute, int(arguments[1]))
	return [
		(
			"%s is %d: %d energy, %d health, %.1f kg carried before it tires you"
			% [
				attributes.rules.attribute_name(attribute),
				attributes.level(attribute),
				attributes.max_energy(),
				attributes.max_health(),
				attributes.carry_capacity(),
			]
		)
	]


func _friendship(arguments: PackedStringArray) -> Array[String]:
	var livestock := _state.livestock
	var maximum := livestock.rules.friendship("max")
	var is_value_valid := (
		arguments.size() == 1 and arguments[0].is_valid_int() and int(arguments[0]) >= 0
	)
	if arguments.size() > 1 or (arguments.size() == 1 and not is_value_valid):
		return ["Usage: %s" % COMMANDS["friendship"][0]]
	var animal := (
		null
		if _state.is_inside()
		else livestock.nearest_pettable(_state.player.position, FRIENDSHIP_SEARCH_RADIUS)
	)
	if animal == null:
		return ["No animal that can be petted near you"]
	if is_value_valid:
		animal.friendship = mini(int(arguments[0]), maximum)
	var petted := "never" if animal.last_petted_day == 0 else "day %d" % animal.last_petted_day
	return [
		(
			"%s: friendship %d of %d, last petted %s"
			% [animal.species, animal.friendship, maximum, petted]
		)
	]


func _spawn(arguments: PackedStringArray) -> Array[String]:
	var is_count_valid := (
		arguments.size() < 2 or (arguments[1].is_valid_int() and int(arguments[1]) > 0)
	)
	if arguments.is_empty() or arguments.size() > 2 or not is_count_valid:
		return ["Usage: %s" % COMMANDS["spawn"][0]]
	var word := arguments[0]
	var count := 1 if arguments.size() < 2 else int(arguments[1])
	# Farm animals and villagers stay in the world: they are part of the state.
	if (
		word == ConsoleHelper.NPC
		or word == ConsoleHelper.ROOSTER
		or LivestockRules.SPECIES.has(StringName(word))
	):
		if _state.is_inside():
			return ["No %s here" % ("villagers" if word == ConsoleHelper.NPC else "animals")]
		var near := _state.player.position
		var spawned := 0
		if word == ConsoleHelper.NPC:
			spawned = _state.npcs.spawn(count, near, _state.world)
		elif word == ConsoleHelper.ROOSTER:
			spawned = _state.livestock.spawn(
				LivestockRules.CHICKEN, count, near, _state.world, LivestockRules.ROOSTER_LOOK
			)
		else:
			spawned = _state.livestock.spawn(StringName(word), count, near, _state.world)
		return ["Spawned %d of %d %s" % [spawned, count, word]]
	var kind := WildlifeRules.RABBIT if word == ConsoleHelper.WILD_RABBIT else StringName(word)
	if not WildlifeRules.KINDS.has(kind):
		return _unknown("animal", word, "spawn")
	if _state.is_inside() or not context.wildlife_spawner.is_valid():
		return ["No animals here"]
	var placed: int = context.wildlife_spawner.call(kind, count)
	return ["Spawned %d of %d %s" % [placed, count, word]]


## The answer to a name that is not a kind (`what` is "animal" or "villager"): it and the names that
## the command takes.
func _unknown(what: String, word: String, command: String) -> Array[String]:
	var lines: Array[String] = ["Unknown %s: %s" % [what, word]]
	lines.append_array(_candidates_text(command))
	return lines


func _spawn_villager(villager_id: String) -> Array[String]:
	var npcs := _state.npcs
	if not npcs.villagers.has(villager_id):
		return _unknown("villager", villager_id, "spawn")
	var here := npcs.find(villager_id)
	if here != null:
		return ["%s is already here" % here.name]
	if _state.is_inside():
		return ["No villagers here"]
	var npc := npcs.spawn_villager(villager_id, _state.player.position, _state.world)
	if npc == null:
		return ["No room for %s here" % villager_id]
	return ["Spawned %s" % npc.name]


## Takes the animals of a kind, or one villager, out of the game and the state that is saved.
## A bare `killall npc` removes the villagers made up (those with no id): the ones written by hand
## are the village's, so each needs its id. A ridden horse is not removed from under the
## player: they get off first, as the dismount needs a free spot that is theirs to choose.
func _killall(arguments: PackedStringArray) -> Array[String]:
	if arguments.is_empty():
		return _candidates_text("killall")
	var word := arguments[0]
	if arguments.size() > 2 or (arguments.size() == 2 and word != ConsoleHelper.NPC):
		return ["Usage: %s" % COMMANDS["killall"][0]]
	if word == ConsoleHelper.NPC and arguments.size() == 1:
		return _kill_made_up_villagers()
	if word == ConsoleHelper.NPC:
		return _kill_villager(arguments[1])
	if _state.npcs.villagers.has(word):
		return _kill_villager(word)
	return _kill_animals(word)


func _kill_animals(word: String) -> Array[String]:
	if word == ConsoleHelper.ROOSTER:
		var roosters := _state.livestock.remove_species(
			LivestockRules.CHICKEN, LivestockRules.ROOSTER_LOOK
		)
		return [_removed_text(roosters, word)]
	if LivestockRules.SPECIES.has(StringName(word)):
		var horse := _state.player.horse
		if horse != null and horse.species == StringName(word):
			return ["You are riding a %s: get off first" % word]
		return [_removed_text(_state.livestock.remove_species(StringName(word)), word)]
	var kind := WildlifeRules.RABBIT if word == ConsoleHelper.WILD_RABBIT else StringName(word)
	if not WildlifeRules.KINDS.has(kind):
		return _unknown("animal", word, "killall")
	var cleared: int = (
		context.wildlife_clearer.call(kind) if context.wildlife_clearer.is_valid() else 0
	)
	return [_removed_text(cleared, word) + " (wild animals are not saved: more may come)"]


func _kill_made_up_villagers() -> Array[String]:
	var removed := 0
	var named: Array[String] = []
	for npc in _state.npcs.all():
		if npc.id.is_empty():
			_state.npcs.remove(npc)
			removed += 1
		else:
			named.append(npc.id)
	var line := (
		_removed_text(removed, ConsoleHelper.NPC) + " (the named villagers stay: killall npc <id>"
	)
	return [line + (", here: %s)" % ", ".join(named) if not named.is_empty() else ")")]


func _kill_villager(villager_id: String) -> Array[String]:
	if not _state.npcs.villagers.has(villager_id):
		return _unknown("villager", villager_id, "killall")
	var npc := _state.npcs.find(villager_id)
	if npc == null:
		return ["%s is not in the world" % villager_id]
	_state.npcs.remove(npc)
	return ["Removed %s" % npc.name]


func _removed_text(count: int, word: String) -> String:
	return "Removed %d %s" % [count, word] if count > 0 else "No %s to remove" % word


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


func _deeds() -> Array[String]:
	var lines: Array[String] = []
	var rules := _state.deeds.rules
	_state.deeds.forget_old()
	for entry in _state.deeds.entries:
		(
			lines
			. append(
				(
					"Day %d, %s: %s %s, seen by %s"
					% [
						entry["day"],
						Sun.time_text(entry["minute"]),
						rules.deed_words(entry["kind"], entry["count"]),
						entry["place"],
						", ".join(entry["witnesses"]),
					]
				)
			)
		)
	if lines.is_empty():
		lines.append("No deeds seen yet")
	return lines


## The stories of a villager's gossip buffer and their long-term memories, oldest first, each with
## its weight, and the topics of the village they know.
func _gossip(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() != 1:
		return ["Usage: %s" % COMMANDS["gossip"][0]]
	var npc := ConsoleHelper.npc_named(arguments[0], context)
	if npc == null:
		return _unknown("villager", arguments[0], "gossip")
	var rules := _state.deeds.rules
	var lines: Array[String] = [
		(
			"%s keeps %d of %d stories and %d of %d memories"
			% [
				npc.name,
				npc.stories.size(),
				_state.deeds.stories_kept,
				npc.memories.size(),
				_state.deeds.memories_kept,
			]
		)
	]
	(
		lines
		. append(
			(
				(
					"Knows %d of %d topics of the village: %s"
					% [
						npc.topics.size(),
						VillageSheet.default_sheet().topic_names().size(),
						", ".join(npc.topics),
					]
				)
				if not npc.topics.is_empty()
				else "Knows no topic of the village"
			)
		)
	)
	for story in npc.stories:
		var told := (
			"seen" if story["how"] == GossipRules.SEEN else "heard from %s" % story["told_by"]
		)
		lines.append(
			(
				"Story, %s, %s: %s"
				% [MemoryWeight.to_word(story["weight"]), told, rules.memory_line(story)]
			)
		)
	for memory in npc.memories:
		lines.append(
			(
				"Memory, %s, day %d: %s"
				% [MemoryWeight.to_word(memory["weight"]), memory["day"], memory["text"]]
			)
		)
	return lines


## The villager with this id, else the first one with this first name (the words of a command
## are lowercase), or null.
## What a villager thinks of the player, in a word and in points; with `points` it sets them.
func _opinion(arguments: PackedStringArray) -> Array[String]:
	var is_setting := arguments.size() == 2
	var is_usage_wrong := arguments.is_empty() or arguments.size() > 2
	if is_usage_wrong or (is_setting and not arguments[1].is_valid_int()):
		return ["Usage: %s" % COMMANDS["opinion"][0]]
	var npc := ConsoleHelper.npc_named(arguments[0], context)
	if npc == null:
		return _unknown("villager", arguments[0], "opinion")
	var rules := _state.deeds.rules
	if is_setting:
		npc.opinion = clampi(int(arguments[1]), rules.opinion_min(), rules.opinion_max())
	return ["%s: %s (%d points)" % [npc.name, rules.opinion_word(npc.opinion), npc.opinion]]


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


func _skip(arguments: PackedStringArray) -> Array[String]:
	var usage: Array[String] = ["Usage: %s" % COMMANDS["skip"][0]]
	if arguments.size() != 1 or arguments[0].length() < 2:
		return usage
	var amount := arguments[0].left(-1)
	var unit := arguments[0].right(1)
	if not SKIP_UNITS.has(unit) or not amount.is_valid_int() or int(amount) <= 0:
		return usage
	var minutes: int = int(amount) * SKIP_UNITS[unit]
	if minutes > MAX_SKIP_MINUTES:
		return ["At most a year (%dd) at once" % GameClock.DAYS_PER_YEAR]
	_state.simulation.skip(minutes)
	return ["Skipped to %s, %s" % [_state.clock.date_text(), _state.clock.time_text()]]


## `crows` shows the flocks and the day's tally; `crows raid` lets every flock raid at once.
func _crows(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() > 1 or (arguments.size() == 1 and arguments[0] != "raid"):
		return ["Usage: %s" % COMMANDS["crows"][0]]
	if arguments.size() == 1:
		_state.crop_raids.raid_hour(_state.clock.total_minutes() / GameClock.MINUTES_PER_HOUR, true)
	var lines := _state.crop_raids.describe()
	lines.append_array(_state.scarecrows.describe())
	return lines
