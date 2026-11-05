class_name Console
extends RefCounted
## The console's commands, run against a GameState: `run` takes a typed line and returns the
## lines to show. Plain logic; ConsoleView is the screen.

## Command name to its usage and what it does, in the order `help` lists them.
const COMMANDS := {
	"help": ["help", "List the commands."],
	"tp": ["tp <x> <y>", "Teleport to a world tile (outside only)."],
	"give": ["give <item> [count]", "Put items in the inventory."],
	"god": ["god", "Toggle invincibility: health never drops (energy still runs out)."],
	"nodrain": ["nodrain", "Toggle: actions cost no energy."],
	"noweight": ["noweight", "Toggle: carried weight doesn't raise costs."],
	"spawn":
	[
		"spawn <kind> [count]",
		"Put animals in view: bird, rabbit, squirrel, deer, bee, butterfly or flock.",
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
	"crop":
	[
		"crop",
		"Show the growth, damage and needs of the crop in front of you or the nearest one.",
	],
}
## How far (in tiles) the `crop` command looks for a crop when none is in front of the player.
const CROP_SEARCH_RADIUS := 4
## Item ids this similar to a misspelt one (see String.similarity) are offered as a guess.
const CLOSE_MATCH_SIMILARITY := 0.4

## Puts animals in view: takes a kind and a count, returns how many it placed. Set by the game
## scene, which has the animals; the console is plain logic.
var wildlife_spawner := Callable()

var _state: GameState


func _init(state: GameState) -> void:
	_state = state


## Runs a line such as "give wood 5" (a leading "/" is optional) and returns the output.
func run(line: String) -> Array[String]:
	var words := _words(line)
	if words.is_empty():
		return []
	var arguments := words.slice(1)
	var cheats := _state.cheats
	var output: Array[String]
	match words[0]:
		"help":
			output = _help()
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
		"spawn":
			output = _spawn(arguments)
		"weather":
			output = _weather(arguments)
		"snow":
			output = _snow(arguments)
		"crop":
			output = _crop()
		_:
			output = ["Unknown command: %s (try help)" % words[0]]
	return output


## The line with its last word completed: a command name, or an item id after `give`. A word
## with several candidates goes as far as they agree; one with none leaves the line alone.
func complete(line: String) -> String:
	var words := _words(line)
	var is_new_word := line.ends_with(" ")
	var word_index := words.size() if is_new_word else maxi(words.size() - 1, 0)
	var typed := "" if is_new_word or words.is_empty() else words[-1]
	var candidates: Array[String] = []
	if word_index == 0:
		candidates.assign(COMMANDS.keys())
	elif word_index == 1 and words[0] == "give":
		candidates = _item_ids()
	elif word_index == 1 and words[0] == "spawn":
		for kind in WildlifeRules.KINDS:
			candidates.append(String(kind))
	elif word_index == 1 and words[0] == "snow":
		candidates = ["auto"]
	elif word_index == 1 and words[0] == "weather":
		for condition in Weather.FORCEABLE:
			candidates.append(String(condition))
		candidates.append("auto")
	candidates = candidates.filter(func(name: String) -> bool: return name.begins_with(typed))
	if candidates.is_empty():
		return line
	var completed := candidates[0] + " " if candidates.size() == 1 else _common_prefix(candidates)
	return line.substr(0, line.length() - typed.length()) + completed


func _words(line: String) -> PackedStringArray:
	return line.strip_edges().trim_prefix("/").to_lower().split(" ", false)


func _help() -> Array[String]:
	var lines: Array[String] = []
	for entry: Array in COMMANDS.values():
		lines.append("%s: %s" % [entry[0], entry[1]])
	return lines


func _tp(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() != 2 or not arguments[0].is_valid_int() or not arguments[1].is_valid_int():
		return ["Usage: %s" % COMMANDS["tp"][0]]
	if _state.is_inside():
		return ["Can't teleport inside a house"]
	var tile := Vector2i(int(arguments[0]), int(arguments[1]))
	if not World.is_in_bounds(tile):
		return ["Tile %d, %d is outside the world" % [tile.x, tile.y]]
	if _state.world.building_at(tile) != null:
		return ["Tile %d, %d is covered by a building" % [tile.x, tile.y]]
	if not _is_walkable_even_if_unloaded(tile):
		return ["Can't walk on tile %d, %d" % [tile.x, tile.y]]
	_state.player.position = Vector2(tile) + Vector2(0.5, 0.5)
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


func _spawn(arguments: PackedStringArray) -> Array[String]:
	var is_count_valid := (
		arguments.size() < 2 or (arguments[1].is_valid_int() and int(arguments[1]) > 0)
	)
	if arguments.is_empty() or arguments.size() > 2 or not is_count_valid:
		return ["Usage: %s" % COMMANDS["spawn"][0]]
	var kind := StringName(arguments[0])
	if not WildlifeRules.KINDS.has(kind):
		return ["Unknown animal: %s" % arguments[0]]
	if _state.is_inside() or not wildlife_spawner.is_valid():
		return ["No animals here"]
	var count := 1 if arguments.size() < 2 else int(arguments[1])
	var placed: int = wildlife_spawner.call(kind, count)
	return ["Spawned %d of %d %s" % [placed, count, kind]]


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
