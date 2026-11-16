class_name SaveActorChecks
extends RefCounted
## The checks of the animals and villagers: the livestock, and for each villager who they are,
## where they live, work and stand, what they remember and know, their friendship with the player
## and the plans of their days, and the log of the deeds they witnessed.

var _ctx: SaveContext


func _init(context: SaveContext) -> void:
	_ctx = context


func check_livestock(game: Dictionary) -> void:
	var livestock: Variant = _ctx.field(game, "livestock", SaveContext.Kind.LIST, "")
	if livestock != null:
		_check_livestock(livestock)


func check_npcs(game: Dictionary) -> void:
	var npcs: Variant = _ctx.field(game, "npcs", SaveContext.Kind.LIST, "")
	if npcs != null:
		for index in npcs.size():
			_check_npc(npcs[index], "npcs %d" % index)


## The log of what villagers saw and did, kept by the village.
func check_deed_log(game: Dictionary) -> void:
	_check_deeds(game, "deeds", "", true)


func _check_livestock(animals: Array) -> void:
	var rules := LivestockRules.default_rules()
	var max_friendship := float(rules.friendship("max"))
	for index in animals.size():
		var animal: Variant = animals[index]
		var path := "livestock %d" % index
		if not animal is Dictionary:
			_ctx.report(path, "should be a dictionary")
			continue
		var species: Variant = _ctx.field(animal, "species", SaveContext.Kind.TEXT, path)
		var look: Variant = _ctx.field(animal, "look", SaveContext.Kind.TEXT, path)
		var tint: Variant = _ctx.field(animal, "tint", SaveContext.Kind.TEXT, path)
		_ctx.field(animal, "position", SaveContext.Kind.POINT, path)
		_ctx.field(animal, "follow_until_minute", SaveContext.Kind.WHOLE, path)
		_ctx.field(animal, "is_saddled", SaveContext.Kind.BOOL, path)
		_ctx.check_between(
			_ctx.field(animal, "stamina", SaveContext.Kind.NUMBER, path), 0.0, 1.0, path, "stamina"
		)
		for need in ["hunger", "thirst"]:
			_ctx.check_between(
				_ctx.field(animal, need, SaveContext.Kind.NUMBER, path), 0.0, 1.0, path, need
			)
		_ctx.check_between(
			_ctx.field(animal, "friendship", SaveContext.Kind.WHOLE, path),
			0.0,
			max_friendship,
			path,
			"friendship"
		)
		_ctx.field(animal, "last_petted_day", SaveContext.Kind.WHOLE, path)
		_ctx.field(animal, "last_petted_asleep_day", SaveContext.Kind.WHOLE, path)
		if tint != null and not Color.html_is_valid(tint):
			_ctx.report(path, "tint %s is not a colour" % tint)
		if species == null or look == null:
			continue
		if not LivestockRules.SPECIES.has(StringName(species)):
			_ctx.add_missing("animal %s" % species, path, _ctx.removing(animals, animal))
		elif not rules.looks(StringName(species)).has(look):
			_ctx.add_missing(
				"look %s of the %s" % [look, species], path, _ctx.removing(animals, animal)
			)


## The house and the workplace of a villager: null, or a building of the world (a workplace may
## be a spot with a name instead).
func _check_places(npc: Dictionary, path: String) -> void:
	if not npc.has("house"):
		_ctx.report(path, "no house")
	elif npc["house"] != null:
		_check_building_reference(npc, "house", path)
	if not npc.has("workplace"):
		_ctx.report(path, "no workplace")
		return
	var workplace: Variant = npc["workplace"]
	if workplace == null:
		return
	if not workplace is Dictionary:
		_ctx.report(path, "workplace should be a dictionary or null")
	elif workplace.has("building"):
		_check_building_reference(workplace, "building", path + " workplace")
	else:
		_ctx.field(workplace, "spot_name", SaveContext.Kind.TEXT, path + " workplace")
		_ctx.field(workplace, "spot_tile", SaveContext.Kind.VECTOR, path + " workplace")


## What `inside` of a villager holds: null, or the origin of a building of the world and where they
## stand in its room.
func _check_inside(npc: Dictionary, path: String) -> void:
	if not npc.has("inside"):
		_ctx.report(path, "no inside")
		return
	var inside: Variant = npc["inside"]
	if inside == null:
		return
	if not inside is Dictionary:
		_ctx.report(path, "inside should be a dictionary or null")
		return
	_check_building_reference(inside, "building", path + " inside")
	_ctx.field(inside, "position", SaveContext.Kind.POINT, path + " inside")


## `owner[key]` is the origin of a building of the world.
func _check_building_reference(owner: Dictionary, key: String, path: String) -> void:
	var origin: Variant = _ctx.field(owner, key, SaveContext.Kind.VECTOR, path)
	if origin != null and not _ctx.has_building_at(SaveCodec.vector_from_json(origin)):
		_ctx.report(path, "%s: no building at %s" % [key, SaveCodec.vector_from_json(origin)])


func _check_npc(npc: Variant, path: String) -> void:
	if not npc is Dictionary:
		_ctx.report(path, "should be a dictionary")
		return
	var sex: Variant = _ctx.field(npc, "sex", SaveContext.Kind.TEXT, path)
	if sex != null and not NpcRules.SEXES.has(StringName(sex)):
		_ctx.report(path, "unknown sex %s" % sex)
	_ctx.field(npc, "name", SaveContext.Kind.TEXT, path)
	var id: Variant = _ctx.field(npc, "id", SaveContext.Kind.TEXT, path)
	# A villager of data/villagers.cfg takes their sheet from the file (see Npc `from_dict`).
	if id == null or not VillagerRules.default_rules().has(id):
		for key in ["trade", "personality", "background", "home", "speech"]:
			_ctx.field(npc, key, SaveContext.Kind.TEXT, path)
		for key in ["likes", "wants", "day", "habits", "avoids", "secrets"]:
			_ctx.field(npc, key, SaveContext.Kind.TEXT, path)
		_ctx.field(npc, "age", SaveContext.Kind.WHOLE, path)
		_ctx.field(npc, "people", SaveContext.Kind.DICT, path)
		_check_texts(npc, "samples", path)
	for key in ["remembered_lines", "opinion", "opinion_day", "opinion_moved_today"]:
		_ctx.field(npc, key, SaveContext.Kind.WHOLE, path)
	_check_friendship(npc, path)
	for key in ["position", "anchor"]:
		_ctx.field(npc, key, SaveContext.Kind.POINT, path)
	_check_places(npc, path)
	_check_inside(npc, path)
	_check_memories(npc, path)
	var appearance: Variant = _ctx.field(npc, "appearance", SaveContext.Kind.DICT, path)
	if appearance != null:
		_ctx.check_appearance(appearance, path + " appearance")
	_check_deeds(npc, "stories", path, false)
	_check_stories(npc, path)
	_check_texts(npc, "topics", path)
	_check_day_plans(npc, path)
	for key in ["chat_history", "uncompacted_lines"]:
		var lines: Variant = _ctx.field(npc, key, SaveContext.Kind.LIST, path)
		if lines != null:
			for index in lines.size():
				_check_chat_line(lines[index], "%s %s %d" % [path, key, index])


## The deeds of `owner[key]`: the entries of the log, or the stories of a villager (without the
## witnesses).
func _check_deeds(owner: Dictionary, key: String, path: String, has_witnesses: bool) -> void:
	var deeds: Variant = _ctx.field(owner, key, SaveContext.Kind.LIST, path)
	if deeds == null:
		return
	for index in deeds.size():
		var deed_path := "%s %d" % [_ctx.join(path, key), index]
		var deed: Variant = deeds[index]
		if not deed is Dictionary:
			_ctx.report(deed_path, "should be a dictionary")
			continue
		for whole in ["day", "minute", "count"]:
			_ctx.field(deed, whole, SaveContext.Kind.WHOLE, deed_path)
		_ctx.field(deed, "place", SaveContext.Kind.TEXT, deed_path)
		var kind: Variant = _ctx.field(deed, "kind", SaveContext.Kind.TEXT, deed_path)
		if kind != null and not GossipRules.KINDS.has(StringName(kind)):
			_ctx.report(deed_path, "unknown deed %s" % kind)
		if has_witnesses:
			_check_texts(deed, "witnesses", deed_path)


## What a villager knows of each story, beyond the deed that _check_deeds has checked.
func _check_stories(npc: Dictionary, path: String) -> void:
	var stories: Variant = npc.get("stories")
	if not stories is Array:
		return
	for index in stories.size():
		var story_path := "%s stories %d" % [path, index]
		var story: Variant = stories[index]
		if not story is Dictionary:
			continue
		for whole in ["hops", "learned_at"]:
			_ctx.field(story, whole, SaveContext.Kind.WHOLE, story_path)
		for text in ["origin", "told_by", "seen_by", "line"]:
			_ctx.field(story, text, SaveContext.Kind.TEXT, story_path)
		for flag in ["personal", "is_judged"]:
			_ctx.field(story, flag, SaveContext.Kind.BOOL, story_path)
		var how: Variant = _ctx.field(story, "how", SaveContext.Kind.TEXT, story_path)
		if how != null and not [GossipRules.SEEN, GossipRules.HEARD].has(StringName(how)):
			_ctx.report(story_path, "unknown way %s" % how)
		var weight: Variant = _ctx.field(story, "weight", SaveContext.Kind.TEXT, story_path)
		if weight != null and not MemoryWeight.WORDS.has(weight):
			_ctx.report(story_path, "unknown weight %s" % weight)


## What a villager has of the player's friendship besides the opinion: days and counts that are not
## negative, what the actions moved today within its cap, and a known bond.
func _check_friendship(npc: Dictionary, path: String) -> void:
	for key in ["last_gift_day", "chat_counted_day", "action_day", "rating_day", "ratings_today"]:
		var value: Variant = _ctx.field(npc, key, SaveContext.Kind.WHOLE, path)
		if value != null and value < 0:
			_ctx.report(_ctx.join(path, key), "should not be negative")
	var moved: Variant = _ctx.field(npc, "action_moved_today", SaveContext.Kind.WHOLE, path)
	var cap := FriendshipRules.default_rules().action_daily_cap()
	if moved != null and absi(moved) > cap:
		_ctx.report(_ctx.join(path, "action_moved_today"), "should be within %d" % cap)
	var requests: Variant = npc.get("ratings_today")
	var request_cap: int = FriendshipRules.default_rules().value("rating", "requests_per_day")
	if _ctx.is_kind(requests, SaveContext.Kind.WHOLE) and requests > request_cap:
		_ctx.report(_ctx.join(path, "ratings_today"), "should be within the requests of a day")
	var rated: Variant = _ctx.field(npc, "rating_moved_today", SaveContext.Kind.WHOLE, path)
	var friendship := FriendshipRules.default_rules()
	if (
		rated != null
		and (
			rated > friendship.rating_daily_cap(&"warm")
			or -rated > friendship.rating_daily_cap(&"rude")
		)
	):
		_ctx.report(
			_ctx.join(path, "rating_moved_today"), "should be within the caps of the ratings"
		)
	var bond: Variant = _ctx.field(npc, "bond", SaveContext.Kind.TEXT, path)
	if bond != null and not FriendshipRules.BONDS.has(StringName(bond)):
		_ctx.report(_ctx.join(path, "bond"), "unknown bond %s" % bond)


## The model's plans for the days of a villager: each with at least one entry `[activity, minute,
## why]`. An activity that data/activities.cfg no longer has takes its plan out.
func _check_day_plans(npc: Dictionary, path: String) -> void:
	var plans: Variant = _ctx.field(npc, "day_plans", SaveContext.Kind.LIST, path)
	if plans == null:
		return
	var rules := ActivityRules.default_rules()
	for index in plans.size():
		var plan_path := "%s day_plans %d" % [path, index]
		var plan: Variant = plans[index]
		if not plan is Dictionary:
			_ctx.report(plan_path, "should be a dictionary")
			continue
		_ctx.field(plan, "day", SaveContext.Kind.WHOLE, plan_path)
		_ctx.field(plan, "whole_day", SaveContext.Kind.BOOL, plan_path)
		_ctx.field(plan, "made_at", SaveContext.Kind.WHOLE, plan_path)
		var entries: Variant = _ctx.field(plan, "entries", SaveContext.Kind.LIST, plan_path)
		if entries == null:
			continue
		if entries.is_empty():
			_ctx.report(plan_path, "has no entries")
		for entry: Variant in entries:
			var is_whole: bool = entry is Array and entry.size() == 3
			if not (
				is_whole
				and _ctx.is_kind(entry[0], SaveContext.Kind.TEXT)
				and _ctx.is_kind(entry[1], SaveContext.Kind.WHOLE)
				and _ctx.is_kind(entry[2], SaveContext.Kind.TEXT)
			):
				_ctx.report(plan_path, "an entry should be [activity, minute, why]")
			elif entry[1] < 0 or entry[1] >= GameClock.MINUTES_PER_DAY:
				_ctx.report(plan_path, "entry minute %d is not in the day" % entry[1])
			elif not rules.has(entry[0]):
				_ctx.add_missing("activity %s" % entry[0], plan_path, _ctx.removing(plans, plan))
				break


func _check_memories(npc: Dictionary, path: String) -> void:
	var memories: Variant = _ctx.field(npc, "memories", SaveContext.Kind.LIST, path)
	if memories == null:
		return
	for index in memories.size():
		var memory_path := "%s memories %d" % [path, index]
		var memory: Variant = memories[index]
		if not memory is Dictionary:
			_ctx.report(memory_path, "should be a dictionary")
			continue
		_ctx.field(memory, "day", SaveContext.Kind.WHOLE, memory_path)
		_ctx.field(memory, "text", SaveContext.Kind.TEXT, memory_path)
		var weight: Variant = _ctx.field(memory, "weight", SaveContext.Kind.TEXT, memory_path)
		if weight != null and not MemoryWeight.WORDS.has(weight):
			_ctx.report(memory_path, "unknown weight %s" % weight)


func _check_texts(owner: Dictionary, key: String, path: String) -> void:
	var texts: Variant = _ctx.field(owner, key, SaveContext.Kind.LIST, path)
	if texts != null and not texts.all(func(text: Variant) -> bool: return text is String):
		_ctx.report("%s %s" % [path, key], "should be a list of text")


func _check_chat_line(line: Variant, path: String) -> void:
	if not line is Dictionary:
		_ctx.report(path, "should be a dictionary")
		return
	_ctx.field(line, "day", SaveContext.Kind.WHOLE, path)
	_ctx.field(line, "minute", SaveContext.Kind.WHOLE, path)
	_ctx.field(line, "from_player", SaveContext.Kind.BOOL, path)
	_ctx.field(line, "text", SaveContext.Kind.TEXT, path)
