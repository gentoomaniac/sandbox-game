class_name Npc
extends RefCounted
## One villager: who they are (name, sex, looks, age, trade and the texts about them), where they
## stand, the anchor they keep near, what they and the player have said to each other and what
## they remember of it. Npcs moves them; NpcView draws them and ChatScreen shows the chat.

enum Activity { IDLE, WALK }

## Their full name, such as "Antje Boysen".
var name: String
var sex: StringName
var appearance: Appearance

# Who they are, as it is told to the language model (see NpcPrompt): written by hand in
# data/villagers.cfg for a villager with an id, and read from it again when a game is loaded (the
# file wins, so edits to it reach saved games), else made up from the tables of data/npcs.cfg
# and kept as they were when the villager came into the world.
## The section of data/villagers.cfg they are, or "" for a villager made up from the tables.
var id := ""
## In years.
var age := 0
## What they do for a living, such as "a farmer's wife".
var trade := ""
## What they are like, in a sentence or two.
var personality := ""
## Their family and their story.
var background := ""
## Where they live.
var home := ""
## How they talk, as a manner that holds in any language.
var speech := ""
## Lines in their voice, which show their manner.
var samples: Array[String] = []
## Their family and close friends, each a villager of data/villagers.cfg: {id: [kind, what they
## think of them]}, such as {"hinrich": ["husband", "Steady ..."]}. None for a made-up villager.
var people := {}
## What they like and dislike.
var likes := ""
## What they want this year.
var wants := ""
## Where they are at what time of the day and the week.
var day := ""
## What they are wont to do.
var habits := ""
## What they don't know or won't talk about.
var avoids := ""
## What they keep to themselves, and only hint at.
var secrets := ""

## Where their feet are, in tiles of the world.
var position: Vector2
## The point they keep near (see Npcs and data/npcs.cfg).
var anchor: Vector2
## The latest lines of the chat, oldest first, each `{day, minute, from_player, text}`: the game
## day and the minute of the day it was said, and whether the player said it. How many are kept is
## a setting (see `drop_old_lines`).
var chat_history: Array[Dictionary] = []
## Their long-term memories, oldest first, each `{day, text, weight}`: the game day, one line such
## as "On the 12th day of Spring, year 1: The neighbour asked after the dyke." (see NpcDialogue
## `compact`) and a MemoryWeight. How many are kept is a setting (see `keep_memories`).
var memories: Array[Dictionary] = []
## The lines that dropped out of `chat_history` and are not in a memory yet, oldest first. Saved,
## so lines whose summing up was still under way when the game was saved are not lost.
var uncompacted_lines: Array[Dictionary] = []
## How many of the oldest lines of `chat_history` are already in a memory (only a save of version
## 20 or older has such lines): they are forgotten, not summed up again, when they drop out.
var remembered_lines := 0
## Their gossip buffer, oldest first: the stories they know, first in, first out (see
## `keep_stories`). A story is `{day, minute, kind, count, place}` (the fact: a deed of the
## player, merged like the entries of DeedLog) and what the villager knows of it: `how` (a
## GossipRules SEEN or HEARD), `origin` (DeedLog `origin_of` the fact as first seen: a villager
## knows one version of a story), `told_by` (a name, or "" if seen), `seen_by` (who saw it first),
## `hops` from that one, `learned_at` (the game minute they came to know it, see GameClock
## `total_minutes`), `line` (the model's wording, "" until it is back: the template line is told
## then), `weight` (a MemoryWeight) and `personal` (whether it touches them).
var stories: Array[Dictionary] = []
## What they think of the player, in points (see GossipRules `opinion_word`). It stays when the
## stories and memories behind it fade, so `forget_all_but_knowledge` leaves it.
var opinion := 0
## The day `opinion_moved_today` counts, and how far the opinion has moved since that day began:
## its sum, up and down (see `change_opinion`).
var opinion_day := 0
var opinion_moved_today := 0
## Whether NpcDialogue is summing up `uncompacted_lines`. Not saved.
var is_compacting := false

# What they are doing is not saved: a loaded villager stands and looks about for what to do.
## The axis direction they look in (UP, DOWN, LEFT or RIGHT).
var facing := Vector2i.DOWN
var activity := Activity.IDLE
var seconds_left := 0.0
## The way they stroll, a unit vector.
var heading := Vector2.ZERO
## The tiles their body last stood on, all walkable: a step that stays on them needs no asking
## the map again (see Npcs).
var free_body_tiles := Rect2i()
## Whether an answer to the player is awaited (see ChatScreen): they say nothing more till then.
## A loaded villager owes none: an answer the game was saved before is lost.
var is_answering := false


func _init(npc_name: String, npc_sex: StringName, look: Appearance, feet: Vector2) -> void:
	name = npc_name
	sex = npc_sex
	appearance = look
	position = feet
	anchor = feet


## A new villager whose sex, name and look follow from `seed_value` alone: the same seed always
## gives the same villager.
static func create(seed_value: int, feet: Vector2, rules: NpcRules) -> Npc:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var npc_sex: StringName = NpcRules.SEXES[rng.randi_range(0, NpcRules.SEXES.size() - 1)]
	var npc_name := rules.pick_name(npc_sex, rng)
	var npc := Npc.new(npc_name, npc_sex, rules.pick_look(npc_sex, rng), feet)
	npc._set_sheet(rules.pick_sheet(npc_sex, npc_name.get_slice(" ", 1), rng))
	return npc


## The villager of data/villagers.cfg with that id.
static func create_villager(villager_id: String, feet: Vector2, villagers: VillagerRules) -> Npc:
	var written := villagers.villager(villager_id)
	var look := Appearance.new()
	look.layers.clear()
	for slot: String in written["look"]:
		look.wear(StringName(slot), written["look"][slot])
	var npc := Npc.new(written["name"], StringName(written["sex"]), look, feet)
	npc.id = villager_id
	npc._set_sheet(written)
	return npc


## The axis direction nearest to `direction`; a tie looks up or down, as the player does.
static func facing_of(direction: Vector2) -> Vector2i:
	if absf(direction.x) > absf(direction.y):
		return Vector2i.RIGHT if direction.x > 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y > 0 else Vector2i.UP


func tile() -> Vector2i:
	return Vector2i(position.floor())


## Looks towards a point of the world, such as the player's feet.
func turn_to(point: Vector2) -> void:
	if not point.is_equal_approx(position):
		facing = facing_of(point - position)


func add_chat_line(day: int, minute: int, from_player: bool, text: String) -> void:
	chat_history.append({"day": day, "minute": minute, "from_player": from_player, "text": text})


## Keeps the last `keep` lines of the chat; the older ones wait in `uncompacted_lines` to be
## made a memory.
func drop_old_lines(keep: int) -> void:
	while chat_history.size() > keep:
		var line: Dictionary = chat_history.pop_front()
		if remembered_lines > 0:
			remembered_lines -= 1
		else:
			uncompacted_lines.append(line)


## Forgets everything but what they know (their sheet): the chat, the gossip buffer and the
## memories.
func forget_all_but_knowledge() -> void:
	stories.clear()
	chat_history.clear()
	uncompacted_lines.clear()
	remembered_lines = 0
	memories.clear()


## Moves the opinion by `points` on game day `today`, as far as the day's cap allows (the sum of
## what moved on the day stays within it either way), and within the bounds of the opinion.
func change_opinion(points: int, today: int, rules: GossipRules) -> void:
	if opinion_day != today:
		opinion_day = today
		opinion_moved_today = 0
	var cap := rules.opinion_daily_cap()
	var moved := clampi(opinion_moved_today + points, -cap, cap) - opinion_moved_today
	opinion_moved_today += moved
	opinion = clampi(opinion + moved, rules.opinion_min(), rules.opinion_max())


## Takes a story into the gossip buffer (the same deed of the same day and place is one story),
## and lets the oldest leave if there are more than `keep` (see `keep_stories`).
func add_story(story: Dictionary, keep: int, keep_in_memory: int) -> void:
	DeedLog.add_to(stories, story)
	keep_stories(keep, keep_in_memory)


## Takes a story they heard into the gossip buffer (their own, whatever it resembles: the caller
## has seen that they lack it), as `add_story` does.
func learn_story(story: Dictionary, keep: int, keep_in_memory: int) -> void:
	stories.append(story.duplicate(true))
	keep_stories(keep, keep_in_memory)


## Keeps `keep` stories at most. The oldest leaves the buffer: a low one is forgotten, any other
## moves its line to long-term memory with its weight (`keep_in_memory` of them are kept).
func keep_stories(keep: int, keep_in_memory: int) -> void:
	while stories.size() > keep:
		var left: Dictionary = stories.pop_front()
		if left["weight"] != MemoryWeight.LOW:
			add_memory(
				GossipRules.default_rules().memory_line(left),
				left["day"],
				left["weight"],
				keep_in_memory
			)


## Remembers `text` of the game `day_of_memory`, and forgets the surplus (see `keep_memories`).
func add_memory(text: String, day_of_memory: int, weight: int, keep: int) -> void:
	memories.append({"day": day_of_memory, "text": text, "weight": weight})
	keep_memories(keep)


## Keeps `keep` memories at most: the lightest goes, between equal weights the oldest.
func keep_memories(keep: int) -> void:
	while memories.size() > keep:
		var forgotten := 0
		for index in range(1, memories.size()):
			var memory := memories[index]
			var lightest := memories[forgotten]
			if (
				memory["weight"] < lightest["weight"]
				or (memory["weight"] == lightest["weight"] and memory["day"] < lightest["day"])
			):
				forgotten = index
		memories.remove_at(forgotten)


func to_dict() -> Dictionary:
	return {
		"name": name,
		"sex": str(sex),
		"appearance": appearance.to_dict(),
		"id": id,
		"age": age,
		"trade": trade,
		"personality": personality,
		"background": background,
		"home": home,
		"speech": speech,
		"samples": samples.duplicate(),
		"people": people.duplicate(true),
		"likes": likes,
		"wants": wants,
		"day": day,
		"habits": habits,
		"avoids": avoids,
		"secrets": secrets,
		"position": SaveCodec.float_vector_to_json(position),
		"anchor": SaveCodec.float_vector_to_json(anchor),
		"chat_history": chat_history.duplicate(true),
		"memories": memories.map(_memory_to_saved),
		"uncompacted_lines": uncompacted_lines.duplicate(true),
		"remembered_lines": remembered_lines,
		"opinion": opinion,
		"opinion_day": opinion_day,
		"opinion_moved_today": opinion_moved_today,
		"stories": stories.map(_story_to_saved),
	}


static func from_dict(data: Dictionary) -> Npc:
	var npc_sex := StringName(data["sex"])
	assert(NpcRules.SEXES.has(npc_sex), "Unknown sex in save: %s" % npc_sex)
	var npc := Npc.new(
		data["name"],
		npc_sex,
		Appearance.from_dict(data["appearance"]),
		SaveCodec.float_vector_from_json(data["position"])
	)
	npc.id = data["id"]
	# The saved sheet stands in for one whose id has left the file.
	var villagers := VillagerRules.default_rules()
	npc._set_sheet(villagers.villager(npc.id) if villagers.has(npc.id) else data)
	npc.anchor = SaveCodec.float_vector_from_json(data["anchor"])
	for line: Dictionary in data["chat_history"]:
		npc.add_chat_line(int(line["day"]), int(line["minute"]), line["from_player"], line["text"])
	for memory: Dictionary in data["memories"]:
		(
			npc
			. memories
			. append(
				{
					"day": int(memory["day"]),
					"text": memory["text"],
					"weight": MemoryWeight.from_word(memory["weight"]),
				}
			)
		)
	for line: Dictionary in data["uncompacted_lines"]:
		npc.uncompacted_lines.append(line)
	for story: Dictionary in data["stories"]:
		npc.stories.append(_story_from_saved(story))
	npc.opinion = int(data["opinion"])
	npc.opinion_day = int(data["opinion_day"])
	npc.opinion_moved_today = int(data["opinion_moved_today"])
	npc.remembered_lines = mini(int(data["remembered_lines"]), npc.chat_history.size())
	return npc


static func _story_to_saved(story: Dictionary) -> Dictionary:
	var saved := DeedLog.to_saved(story)
	saved["how"] = str(story["how"])
	saved["weight"] = MemoryWeight.to_word(story["weight"])
	return saved


static func _story_from_saved(saved: Dictionary) -> Dictionary:
	var story := DeedLog.from_saved(saved)
	story["how"] = StringName(saved["how"])
	story["hops"] = int(saved["hops"])
	story["learned_at"] = int(saved["learned_at"])
	story["weight"] = MemoryWeight.from_word(saved["weight"])
	return story


static func _memory_to_saved(memory: Dictionary) -> Dictionary:
	return {
		"day": memory["day"],
		"text": memory["text"],
		"weight": MemoryWeight.to_word(memory["weight"]),
	}


## Takes who they are from a dictionary with the keys of the same names: a sheet of
## data/villagers.cfg, one drawn by NpcRules `pick_sheet`, or a save.
func _set_sheet(data: Dictionary) -> void:
	age = int(data["age"])
	trade = data["trade"]
	personality = data["personality"]
	background = data["background"]
	home = data["home"]
	speech = data["speech"]
	samples.assign(data["samples"])
	people = data["people"].duplicate(true)
	likes = data["likes"]
	wants = data["wants"]
	day = data["day"]
	habits = data["habits"]
	avoids = data["avoids"]
	secrets = data["secrets"]
