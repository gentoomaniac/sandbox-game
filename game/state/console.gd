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
	"noneeds": ["noneeds", "Toggle: the farm animals' hunger and thirst do not rise."],
	"noclip": ["noclip", "Toggle: walk through anything (indoors within the room)."],
	"freeze": ["freeze", "Toggle: time stands still (you and the animals still move)."],
	"reset": ["reset", "Put you in your bed, the one you wake in (inside or out)."],
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
		"weather [clear|rain|snow|fog|wind|storm|thunder|auto]",
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
	"friendship":
	[
		"friendship [0..100]",
		"Show the friendship of the animal nearest to you, or set it.",
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
## missing or unknown name list the candidates of the kinds in LISTED_KINDS.
const ARGUMENTS := {
	"help": [&"command"],
	"tp": [&"number", &"number"],
	"give": [&"item", &"number"],
	"spawn": [&"animal", &"number"],
	"killall": [&"animal"],
	"weather": [&"weather"],
	"snow": [&"snow"],
	"skill": [&"skill", &"number"],
	"play": [&"track"],
}
## The commands that take an animal kind, or `npc` and the id of a villager written by hand (see
## VillagerRules): `spawn` puts them in the world and `killall` takes them out.
const KIND_COMMANDS: Array[String] = ["spawn", "killall"]
## `spawn npc` takes the id of a villager written by hand where the other kinds take a count, or a
## count; `killall npc` takes that id.
const NPC_ARGUMENTS: Array[StringName] = [&"animal", &"villager"]
## The argument kinds whose candidates `_candidates_text` lists: the names a command takes. Items
## are too many to list (Tab completes them) and the other kinds are numbers.
const LISTED_KINDS: Array[StringName] = [&"animal", &"villager", &"weather", &"snow", &"track"]
## The most characters of a listed line, so the log shows it whole.
const LIST_LINE_LENGTH := 70
## Minutes per unit of the `skip` command, and the longest skip (a year).
const SKIP_UNITS := {"m": 1, "h": GameClock.MINUTES_PER_HOUR, "d": GameClock.MINUTES_PER_DAY}
const MAX_SKIP_MINUTES := GameClock.DAYS_PER_YEAR * GameClock.MINUTES_PER_DAY
## The snow values Tab offers; any number from 0 to 1 works.
const SNOW_CANDIDATES: Array[String] = ["auto", "0", "0.5", "1"]
## How far (in tiles) the `friendship` command looks for an animal.
const FRIENDSHIP_SEARCH_RADIUS := 3.0
## How far (in tiles) the `crop` command looks for a crop when none is in front of the player.
const CROP_SEARCH_RADIUS := 4
## What `spawn` calls a villager (see Npcs).
const NPC := "npc"
## What `spawn` calls the wild rabbit (WildlifeRules.RABBIT): a plain rabbit is a tame one of the
## livestock.
const WILD_RABBIT := "wild_rabbit"
## What `play` and `stop` say when the game scene gave the console no music.
const NO_MUSIC := "No music here"
## Item ids this similar to a misspelt one (see String.similarity) are offered as a guess.
const CLOSE_MATCH_SIMILARITY := 0.4

## Puts animals in view: takes a kind and a count, returns how many it placed. Set by the game
## scene, which has the animals; the console is plain logic.
var wildlife_spawner := Callable()
## Takes the wild animals of a kind away: takes a kind, returns how many it took. Set by the game
## scene, as the spawner is.
var wildlife_clearer := Callable()

## The names of the pieces `play` takes: returns an Array[String]. Set by the game scene, which
## finds the music; the console is plain logic.
var music_tracks := Callable()
## Starts a piece of music: takes its name (one of `music_tracks`), returns the line to show.
var music_player := Callable()
## Fades the music out.
var music_stopper := Callable()

var _state: GameState


func _init(state: GameState) -> void:
	_state = state


## Runs a line such as "give logs 5" (a leading "/" is optional) and returns the output.
func run(line: String) -> Array[String]:
	var words := _words(line)
	if words.is_empty():
		return []
	var arguments := words.slice(1)
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
			output = [_toggle_message("God mode", cheats.is_god)]
		"nodrain":
			cheats.is_drain_off = not cheats.is_drain_off
			output = [_toggle_message("No drain", cheats.is_drain_off)]
		"noweight":
			cheats.is_weight_off = not cheats.is_weight_off
			output = [_toggle_message("No weight", cheats.is_weight_off)]
		"nocost":
			cheats.is_cost_off = not cheats.is_cost_off
			output = [_toggle_message("No cost", cheats.is_cost_off)]
		"noneeds":
			cheats.are_needs_off = not cheats.are_needs_off
			output = [_toggle_message("No needs", cheats.are_needs_off)]
		"noclip":
			cheats.is_noclip = not cheats.is_noclip
			output = [_toggle_message("No clip", cheats.is_noclip)]
			# Off inside a lake or a wall: onto the nearest ground they fit on.
			if not cheats.is_noclip and not _state.put_player_on_free_ground():
				output.append("No free ground near you: walk out, or turn noclip on again")
		"freeze":
			cheats.is_time_stopped = not cheats.is_time_stopped
			output = [_toggle_message("Time stopped", cheats.is_time_stopped)]
		"reset":
			_state.go_to_home_bed()
			output = ["Back in bed"]
		"killall":
			output = _killall(arguments)
		"spawn":
			if arguments.is_empty():
				output = _candidates_text("spawn")
			elif arguments.size() == 2 and arguments[0] == NPC and not arguments[1].is_valid_int():
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
			output = _crop()
		"skill":
			output = _skill(arguments)
		"friendship":
			output = _friendship(arguments)
		"play":
			output = _play(arguments)
		"stop":
			if music_stopper.is_valid():
				music_stopper.call()
				output = ["Music fading out"]
			else:
				output = [NO_MUSIC]
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
	var kind := &"command"  # Past the last argument the kind stays empty: nothing to offer.
	if word_index > 0:
		var kinds: Array = ARGUMENTS.get(words[0], [])
		if words[0] in KIND_COMMANDS and words.size() > 1 and words[1] == NPC:
			kinds = NPC_ARGUMENTS
		kind = kinds[word_index - 1] if word_index <= kinds.size() else &""
	var offered := candidates(kind)
	if word_index == 1 and words[0] in KIND_COMMANDS:
		offered.append_array(candidates(&"villager"))  # `spawn antje` as well as `spawn npc antje`
	offered = offered.filter(func(name: String) -> bool: return name.begins_with(typed))
	if offered.is_empty():
		return line
	var completed := offered[0] + " " if offered.size() == 1 else _common_prefix(offered)
	return line.substr(0, line.length() - typed.length()) + completed


## What Tab offers for an argument of this kind (see ARGUMENTS).
func candidates(kind: StringName) -> Array[String]:
	var values: Array[String] = []
	match kind:
		&"command":
			values.assign(COMMANDS.keys())
		&"item":
			values = _item_ids()
		&"animal":
			values.append(NPC)
			for species in LivestockRules.SPECIES:
				values.append(String(species))
			for animal in WildlifeRules.KINDS:
				values.append(WILD_RABBIT if animal == WildlifeRules.RABBIT else String(animal))
		&"villager":
			values = _state.npcs.villagers.ids()
		&"weather":
			for condition in Weather.FORCEABLE:
				values.append(String(condition))
			values.append("auto")
		&"snow":
			values.assign(SNOW_CANDIDATES)
		&"skill":
			for skill in _state.player.skills.rules.skill_ids():
				values.append(String(skill))
		&"track":
			if music_tracks.is_valid():
				values.assign(music_tracks.call())
	return values


func _words(line: String) -> PackedStringArray:
	return line.strip_edges().trim_prefix("/").to_lower().split(" ", false)


func _help(arguments: PackedStringArray) -> Array[String]:
	var lines: Array[String] = []
	if arguments.size() > 1:
		return ["Usage: %s" % COMMANDS["help"][0]]
	if arguments.size() == 1:
		if not COMMANDS.has(arguments[0]):
			return ["Unknown command: %s (try help)" % arguments[0]]
		var entry: Array = COMMANDS[arguments[0]]
		lines.append("%s: %s" % [entry[0], entry[1]])
		lines.append_array(_candidates_text(arguments[0]))
		return lines
	for entry: Array in COMMANDS.values():
		lines.append("%s: %s" % [entry[0], entry[1]])
	return lines


## The names the command takes, from the same candidates Tab completes, one line per kind of
## argument (a long list continues on the next lines).
func _candidates_text(command: String) -> Array[String]:
	var lines: Array[String] = []
	var kinds: Array = ARGUMENTS.get(command, [])
	if command in KIND_COMMANDS:
		kinds = kinds + [&"villager"]
	for kind: StringName in kinds:
		if LISTED_KINDS.has(kind):
			lines.append_array(_candidates_lines(kind))
	return lines


## The names of one kind of argument, wrapped into lines that fit the log.
func _candidates_lines(kind: StringName) -> Array[String]:
	var lines: Array[String] = []
	var line := "%s:" % kind
	for name in candidates(kind):
		if line.length() + name.length() + 2 > LIST_LINE_LENGTH:
			lines.append(line)
			line = " "
		line += " %s," % name
	lines.append(line.trim_suffix(","))
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
		return _unknown_item(arguments[0])
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
	if word == NPC or LivestockRules.SPECIES.has(StringName(word)):
		if _state.is_inside():
			return ["No %s here" % ("villagers" if word == NPC else "animals")]
		var near := _state.player.position
		var spawned := (
			_state.npcs.spawn(count, near, _state.world)
			if word == NPC
			else _state.livestock.spawn(StringName(word), count, near, _state.world)
		)
		return ["Spawned %d of %d %s" % [spawned, count, word]]
	var kind := WildlifeRules.RABBIT if word == WILD_RABBIT else StringName(word)
	if not WildlifeRules.KINDS.has(kind):
		return _unknown("animal", word, "spawn")
	if _state.is_inside() or not wildlife_spawner.is_valid():
		return ["No animals here"]
	var placed: int = wildlife_spawner.call(kind, count)
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
	if arguments.size() > 2 or (arguments.size() == 2 and word != NPC):
		return ["Usage: %s" % COMMANDS["killall"][0]]
	if word == NPC and arguments.size() == 1:
		return _kill_made_up_villagers()
	if word == NPC:
		return _kill_villager(arguments[1])
	if _state.npcs.villagers.has(word):
		return _kill_villager(word)
	return _kill_animals(word)


func _kill_animals(word: String) -> Array[String]:
	if LivestockRules.SPECIES.has(StringName(word)):
		var horse := _state.player.horse
		if horse != null and horse.species == StringName(word):
			return ["You are riding a %s: get off first" % word]
		return [_removed_text(_state.livestock.remove_species(StringName(word)), word)]
	var kind := WildlifeRules.RABBIT if word == WILD_RABBIT else StringName(word)
	if not WildlifeRules.KINDS.has(kind):
		return _unknown("animal", word, "killall")
	var cleared: int = wildlife_clearer.call(kind) if wildlife_clearer.is_valid() else 0
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
	var line := _removed_text(removed, NPC) + " (the named villagers stay: killall npc <id>"
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
			return ["Weather follows the simulation"]
		if not Weather.FORCEABLE.has(StringName(word)):
			return ["Usage: %s" % COMMANDS["weather"][0]]
		_state.weather_override = StringName(word)
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


func _play(arguments: PackedStringArray) -> Array[String]:
	if not music_player.is_valid():
		return [NO_MUSIC]
	if arguments.size() != 1:
		var lines: Array[String] = ["Usage: %s" % COMMANDS["play"][0]]
		lines.append_array(_candidates_text("play"))
		return lines
	var track := track_named(arguments[0], candidates(&"track"))
	if track.is_empty():
		return _unknown("track", arguments[0], "play")
	var line: String = music_player.call(track)
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


func _crop() -> Array[String]:
	var crop := _nearest_crop()
	if crop == null:
		return ["No crop near you"]
	var lines: Array[String] = []
	lines.assign(CropLife.describe(crop))
	lines.append("Soil moisture %.2f" % _state.world.moisture_at(crop.pos))
	return lines


## The crop in front of the player, else the nearest one within CROP_SEARCH_RADIUS.
func _nearest_crop() -> WorldObject:
	if _state.is_inside():
		return null
	var in_front := _state.world.object_at(_state.player.facing_tile())
	if in_front != null and in_front.is_crop():
		return in_front
	var nearest: WorldObject = null
	var player_tile := _state.player.tile()
	for y in range(-CROP_SEARCH_RADIUS, CROP_SEARCH_RADIUS + 1):
		for x in range(-CROP_SEARCH_RADIUS, CROP_SEARCH_RADIUS + 1):
			var object := _state.world.object_at(player_tile + Vector2i(x, y))
			if object == null or not object.is_crop():
				continue
			if (
				nearest == null
				or Vector2i(x, y).length_squared() < (nearest.pos - player_tile).length_squared()
			):
				nearest = object
	return nearest


func _unknown_item(typed: String) -> Array[String]:
	var close: Array[String] = []
	for item in _item_ids():
		if item.similarity(typed) >= CLOSE_MATCH_SIMILARITY:
			close.append(item)
	var lines: Array[String] = ["Unknown item: %s" % typed]
	if not close.is_empty():
		lines.append("Did you mean: %s" % ", ".join(close))
	return lines


func _item_ids() -> Array[String]:
	var ids: Array[String] = []
	for item: StringName in ItemTypes.TYPES:
		ids.append(String(item))
	return ids


func _toggle_message(cheat: String, is_on: bool) -> String:
	return "%s %s" % [cheat, "on" if is_on else "off"]


func _common_prefix(texts: Array[String]) -> String:
	var prefix := texts[0]
	for text in texts:
		while not text.begins_with(prefix):
			prefix = prefix.substr(0, prefix.length() - 1)
	return prefix
