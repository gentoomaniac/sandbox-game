class_name DeedLog
extends RefCounted
## What the player does near villagers (design/villagers/gossip.md, Deeds): it listens to the
## finished actions of the player (GameState `action_done`) and writes down each one that is a
## deed and that a villager saw, as
## `{day, minute, kind, count, place, witnesses}`: the day and the minute of the day of the last
## deed of the entry, its kind (a GossipRules kind), how many times it was done, the place in words
## and the names of the villagers who saw it. Deeds of the same kind and place on the same day
## merge into one entry, adding up the count and the witnesses; an entry is kept for
## GossipRules `keep_days`. Only the world is watched: a deed inside a house is not seen.
##
## Every witness also gets the deed as a story in `Npc.stories` (`{day, minute, kind, count,
## place}`, merged the same way), which the chat prompt tells.

## The oldest entry first.
var entries: Array[Dictionary] = []
var rules := GossipRules.default_rules()
var _npcs: Npcs
var _clock: GameClock


func _init(npcs: Npcs, clock: GameClock) -> void:
	_npcs = npcs
	_clock = clock
	clock.new_day.connect(_on_new_day)


## The kind of deed that a finished action is, or "" for one that is none. A hammer `take_down` of
## a placed object and the shovel digging up a bush are no deeds: the log has no kind for them.
static func kind_of(outcome: ActionOutcome) -> StringName:
	var is_object_known := WorldObjectTypes.TYPES.has(outcome.object)
	var object_data: Dictionary = WorldObjectTypes.TYPES[outcome.object] if is_object_known else {}
	match outcome.kind:
		ActionOutcome.TILL:
			return GossipRules.TILLED
		ActionOutcome.PLANT:
			return GossipRules.SOWED if object_data.has("growth_stages") else &""
		ActionOutcome.HARVEST:
			return GossipRules.HARVESTED
		ActionOutcome.MOW:
			return GossipRules.MOWED
		ActionOutcome.DIG:
			return GossipRules.DUG_CLAY if outcome.items.has(ItemTypes.CLAY) else &""
		ActionOutcome.BREAK:
			return GossipRules.FELLED if object_data.has("trunk") else &""
		ActionOutcome.PLACE:
			return GossipRules.FENCED if object_data.has("connects") else &""
		ActionOutcome.BUILD:
			return GossipRules.BUILT
		ActionOutcome.DEMOLISH:
			return GossipRules.TOOK_DOWN
	return &""


## Adds `deed` to `list` (of entries or stories), or to the one of the same day, kind and place:
## the counts add up, and the entry takes the minute of the later deed and, if the deed has
## `witnesses`, the names it did not have.
static func add_to(list: Array[Dictionary], deed: Dictionary) -> void:
	for entry in list:
		if (
			entry["day"] == deed["day"]
			and entry["kind"] == deed["kind"]
			and entry["place"] == deed["place"]
		):
			entry["count"] += deed["count"]
			entry["minute"] = deed["minute"]
			for name: String in deed.get("witnesses", []):
				if not entry["witnesses"].has(name):
					entry["witnesses"].append(name)
			return
	list.append(deed.duplicate(true))


## Takes out of `list` what is `keep_days` days or more old on `today`.
static func drop_old(list: Array[Dictionary], today: int, keep_days: int) -> void:
	list.assign(
		list.filter(func(entry: Dictionary) -> bool: return today - entry["day"] < keep_days)
	)


## Writes down the action if it is a deed that some villager saw.
func record(outcome: ActionOutcome) -> void:
	var kind := kind_of(outcome)
	if kind == &"" or not outcome.map is World:
		return
	var spot := Vector2(outcome.tile) + Vector2(0.5, 0.5)
	var is_night := _npcs.is_rest_time(_clock.day, _clock.minute_of_day)
	var witnesses := _npcs.all().filter(
		func(npc: Npc) -> bool: return npc.position.distance_to(spot) <= rules.radius(is_night)
	)
	if witnesses.is_empty():
		return
	var deed := {
		"day": _clock.day,
		"minute": _clock.minute_of_day,
		"kind": kind,
		"count": 1,
		"place": _place_of(outcome, spot),
		"witnesses": witnesses.map(func(npc: Npc) -> String: return npc.name),
	}
	add_to(entries, deed)
	deed.erase("witnesses")
	for npc: Npc in witnesses:
		add_to(npc.stories, deed)
	forget_old()


## Forgets what is too old on the day of the clock: the entries of the log and the stories of
## the villagers.
func forget_old() -> void:
	drop_old(entries, _clock.day, rules.keep_days())
	for npc in _npcs.all():
		drop_old(npc.stories, _clock.day, rules.keep_days())


## The save data of the log.
func to_array() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	data.assign(entries.map(to_saved))
	return data


## Loads the log, after the villagers with their stories, and forgets what has grown old.
func load_array(data: Array) -> void:
	entries.assign(data.map(from_saved))
	forget_old()


## A deed (an entry or a story) as save data: the kind is text.
static func to_saved(deed: Dictionary) -> Dictionary:
	var saved := deed.duplicate(true)
	saved["kind"] = str(deed["kind"])
	return saved


## A deed from save data: the numbers are whole again (JSON has only floats) and the kind a name.
static func from_saved(saved: Dictionary) -> Dictionary:
	var deed := saved.duplicate(true)
	deed["kind"] = StringName(saved["kind"])
	for key in ["day", "minute", "count"]:
		deed[key] = int(saved[key])
	return deed


## "by Antje's house" for the villager whose anchor is nearest within the daytime radius of the
## spot, else the word of the ground there.
func _place_of(outcome: ActionOutcome, spot: Vector2) -> String:
	var nearest: Npc
	var nearest_distance := rules.radius(false)
	for npc in _npcs.all():
		var distance := npc.anchor.distance_to(spot)
		if distance <= nearest_distance:
			nearest = npc
			nearest_distance = distance
	if nearest != null:
		return rules.house_place(nearest.name.get_slice(" ", 0))
	return rules.ground_place(outcome.map.tile_at(outcome.tile).terrain)


func _on_new_day(_day: int) -> void:
	forget_old()
