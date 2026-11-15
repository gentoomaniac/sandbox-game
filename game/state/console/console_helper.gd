class_name ConsoleHelper
extends RefCounted
## What several console commands share: the words they take, the names Tab offers for each kind of
## argument, and the answers to a name that is not known.

## What `home` and `work` take after the villager.
const PLACE_WORDS: Array[String] = ["here", "none"]
## The word of `goto` for the tile the player stands on.
const HERE := "here"
## The word of `routine` for the whole day.
const WHOLE_DAY := "day"
## What `spawn` calls a villager (see Npcs).
const NPC := "npc"
## What `spawn` calls the wild rabbit (WildlifeRules.RABBIT): a plain rabbit is a tame one of the
## livestock.
const WILD_RABBIT := "wild_rabbit"
## What `spawn` and `killall` call the rooster: the chicken of LivestockRules.ROOSTER_LOOK.
const ROOSTER := "rooster"
## What `play` and `stop` say when the game scene gave the console no music.
const NO_MUSIC := "No music here"
## What `map` says when the game scene gave the console no map.
const NO_MAP := "No map here"
## The snow values Tab offers; any number from 0 to 1 works.
const SNOW_CANDIDATES: Array[String] = ["auto", "0", "0.5", "1"]
## The kinds of `spawn npc` and `killall npc`: they take the id of a villager written by hand (see
## VillagerRules) where the other kinds take a count, or a count.
const NPC_ARGUMENTS: Array[StringName] = [&"animal", &"villager"]
## The argument kinds whose candidates `help` lists: the names a command takes. Items are too many
## to list (Tab completes them) and the other kinds are numbers.
const LISTED_KINDS: Array[StringName] = [&"animal", &"villager", &"weather", &"snow", &"track"]
## The most characters of a listed line, so the log shows it whole.
const LIST_LINE_LENGTH := 70
## Item ids this similar to a misspelt one (see String.similarity) are offered as a guess.
const CLOSE_MATCH_SIMILARITY := 0.4


## What Tab offers for an argument of this kind (see ConsoleCommand.argument_kinds).
static func candidates(kind: StringName, context: ConsoleContext) -> Array[String]:
	var values: Array[String] = []
	match kind:
		&"command":
			for command in context.commands:
				values.append(command.name())
		&"item":
			values = item_ids()
		&"animal":
			values.append(NPC)
			for species in LivestockRules.SPECIES:
				values.append(String(species))
			values.append(ROOSTER)
			for animal in WildlifeRules.KINDS:
				values.append(WILD_RABBIT if animal == WildlifeRules.RABBIT else String(animal))
		&"villager":
			values = context.state.npcs.villagers.ids()
		&"place":
			values.assign(PLACE_WORDS)
		&"destination":
			values.append(HERE)
		&"routine_view":
			values.append(WHOLE_DAY)
		&"weather":
			for condition in Weather.FORCEABLE:
				values.append(String(condition))
			values.append("auto")
		&"snow":
			values.assign(SNOW_CANDIDATES)
		&"shop_action":
			values.append("restock")
		&"skill":
			for skill in context.state.player.skills.rules.skill_ids():
				values.append(String(skill))
		&"attribute":
			for attribute in context.state.player.attributes.rules.attribute_ids():
				values.append(String(attribute))
		&"track":
			if context.music_tracks.is_valid():
				values.assign(context.music_tracks.call())
	return values


## The names the command takes, from the same candidates Tab completes, one line per kind of
## argument (a long list continues on the next lines).
static func candidates_text(command: ConsoleCommand, context: ConsoleContext) -> Array[String]:
	var lines: Array[String] = []
	var kinds := command.argument_kinds()
	if command.takes_villager_ids():
		kinds.append(&"villager")
	for kind in kinds:
		if LISTED_KINDS.has(kind):
			lines.append_array(candidates_lines(kind, context))
	return lines


## The names of one kind of argument, wrapped into lines that fit the log.
static func candidates_lines(kind: StringName, context: ConsoleContext) -> Array[String]:
	var lines: Array[String] = []
	var line := "%s:" % kind
	for name in candidates(kind, context):
		if line.length() + name.length() + 2 > LIST_LINE_LENGTH:
			lines.append(line)
			line = " "
		line += " %s," % name
	lines.append(line.trim_suffix(","))
	return lines


## The answer to a name that is not a kind (`what` is "animal" or "villager"): it and the names that
## the command takes.
static func unknown(
	what: String, word: String, command: ConsoleCommand, context: ConsoleContext
) -> Array[String]:
	var lines: Array[String] = ["Unknown %s: %s" % [what, word]]
	lines.append_array(candidates_text(command, context))
	return lines


static func unknown_item(typed: String) -> Array[String]:
	var close: Array[String] = []
	for item in item_ids():
		if item.similarity(typed) >= CLOSE_MATCH_SIMILARITY:
			close.append(item)
	var lines: Array[String] = ["Unknown item: %s" % typed]
	if not close.is_empty():
		lines.append("Did you mean: %s" % ", ".join(close))
	return lines


static func item_ids() -> Array[String]:
	var ids: Array[String] = []
	for item: StringName in ItemTypes.TYPES:
		ids.append(String(item))
	return ids


## The villager with this id, else the first one with this first name (the words of a command are
## lowercase), or null.
static func npc_named(word: String, context: ConsoleContext) -> Npc:
	var npc := context.state.npcs.find(word)
	if npc != null:
		return npc
	for each in context.state.npcs.all():
		if each.name.get_slice(" ", 0).to_lower() == word:
			return each
	return null


## The kind of wild animal a word of `spawn` and `killall` stands for.
static func wildlife_kind(word: String) -> StringName:
	return WildlifeRules.RABBIT if word == WILD_RABBIT else StringName(word)


static func toggle_message(cheat: String, is_on: bool) -> String:
	return "%s %s" % [cheat, "on" if is_on else "off"]


static func common_prefix(texts: Array[String]) -> String:
	var prefix := texts[0]
	for text in texts:
		while not text.begins_with(prefix):
			prefix = prefix.substr(0, prefix.length() - 1)
	return prefix
