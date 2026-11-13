class_name GossipRules
extends RefCounted
## The words and numbers of the deed log, read from data/gossip.cfg (see there for what each key
## means): how far a villager sees, how long a deed is kept, the words of a deed, of a count, of a
## place and of the story a villager is told, which names the teller if it was heard. How stories
## spread is SpreadRules, of the same file.

const DEFAULT_PATH := "res://data/gossip.cfg"

const FELLED := &"felled"
const BUILT := &"built"
const TOOK_DOWN := &"took_down"
const FENCED := &"fenced"
const TILLED := &"tilled"
const SOWED := &"sowed"
const HARVESTED := &"harvested"
const DUG_CLAY := &"dug_clay"
const MOWED := &"mowed"
## The kinds of deed, each a section of the file.
const KINDS: Array[StringName] = [
	FELLED, BUILT, TOOK_DOWN, FENCED, TILLED, SOWED, HARVESTED, DUG_CLAY, MOWED
]
## How a villager came to know a story.
const SEEN := &"seen"
const HEARD := &"heard"
const KIND_KEYS: Array[String] = ["one", "many", "change"]
const MAX_CHANGE := 2

const REQUIRED_KEYS := {
	"witnesses": ["radius_tiles", "night_radius_tiles"],
	"log": ["keep_days"],
	"opinion":
	[
		"step_points",
		"heard_share",
		"min_points",
		"max_points",
		"daily_cap_points",
		"cold_below",
		"warm_from",
	],
	"places": ["house"],
	"counts": ["words"],
	"story":
	[
		"today",
		"yesterday",
		"earlier",
		"memory",
		"heard_today",
		"heard_yesterday",
		"heard_earlier",
		"heard_memory",
		"voiced_today",
		"voiced_yesterday",
		"voiced_earlier",
		"voiced_memory",
	],
}

static var _default: GossipRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> GossipRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> GossipRules:
	var rules := GossipRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what". The values are only checked once every key is
## there.
func problems() -> Array[String]:
	var bad: Array[String] = []
	for section: String in REQUIRED_KEYS:
		for key: String in REQUIRED_KEYS[section]:
			if not _values.get(section, {}).has(key):
				bad.append("[%s] no %s" % [section, key])
	for kind in KINDS:
		for key in KIND_KEYS:
			if not _values.get(str(kind), {}).has(key):
				bad.append("[%s] no %s" % [kind, key])
	for terrain: String in Tile.Terrain.keys():
		if not _values.get("places", {}).has(terrain.to_lower()):
			bad.append("[places] no %s" % terrain.to_lower())
	if not bad.is_empty():
		return bad
	if radius(true) > radius(false):
		bad.append("[witnesses] night_radius_tiles must not be above radius_tiles")
	if keep_days() < 1:
		bad.append("[log] keep_days must be at least 1")
	if opinion_min() > 0 or opinion_max() < 0:
		bad.append("[opinion] min_points must not be above 0 nor max_points below it")
	if opinion_cold_below() > opinion_warm_from():
		bad.append("[opinion] cold_below must not be above warm_from")
	for kind in KINDS:
		if absi(opinion_change(kind)) > MAX_CHANGE:
			bad.append("[%s] change must be from -%d to %d" % [kind, MAX_CHANGE, MAX_CHANGE])
	return bad


func is_valid() -> bool:
	return problems().is_empty()


## How many tiles from a deed a villager sees it, at night or by day.
func radius(is_night: bool) -> float:
	return float(_values["witnesses"]["night_radius_tiles" if is_night else "radius_tiles"])


## How many days a deed is kept, today's included.
func keep_days() -> int:
	return int(_values["log"]["keep_days"])


## The points that a change of `steps` steps (-2 to 2) of the opinion comes to for a story that
## the villager saw or heard (`how`): in full if seen, else by the share of the data file.
func opinion_points(steps: int, how: StringName) -> int:
	var share := 1.0 if how == SEEN else float(_values["opinion"]["heard_share"])
	return roundi(steps * float(_values["opinion"]["step_points"]) * share)


## The lowest and the highest opinion of the player a villager can have, in points.
func opinion_min() -> int:
	return int(_values["opinion"]["min_points"])


func opinion_max() -> int:
	return int(_values["opinion"]["max_points"])


## The most points the opinion of a villager moves in a day, up or down.
func opinion_daily_cap() -> int:
	return int(_values["opinion"]["daily_cap_points"])


## Below this many points the villager is cold towards the player.
func opinion_cold_below() -> int:
	return int(_values["opinion"]["cold_below"])


## From this many points the villager is warm towards the player.
func opinion_warm_from() -> int:
	return int(_values["opinion"]["warm_from"])


## The opinion in a word (`cold`, `neutral` or `warm`), which the chat prompt tells.
func opinion_word(points: int) -> StringName:
	if points < opinion_cold_below():
		return &"cold"
	return &"warm" if points >= opinion_warm_from() else &"neutral"


## What the villagers who saw a deed of this kind think more (or less) of the player.
func opinion_change(kind: StringName) -> int:
	return int(_values[str(kind)]["change"])


## The deed in words, to follow "the newcomer": "fell 7 trees", "fell a dozen trees".
func deed_words(kind: StringName, count: int) -> String:
	var words: String = _values[str(kind)]["one" if count == 1 else "many"]
	return words.format({"count": _values["counts"]["words"].get(count, count)})


## "by Antje's house", for the villager with this first name.
func house_place(first_name: String) -> String:
	return str(_values["places"]["house"]).format({"name": first_name})


## "out on the marsh": where there is no house in reach, by the ground.
func ground_place(terrain: Tile.Terrain) -> String:
	return _values["places"][Tile.Terrain.keys()[terrain].to_lower()]


## What a villager is told of a story (a deed, see DeedLog) `days_ago` days after it: "Today you
## saw the newcomer fell 7 trees by Antje's house.", or, if they heard it, "Today Moiken told you
## that the newcomer was seen to fell 7 trees by Antje's house."; or, if the model has put it in
## their words, "Today, in your own words: ...".
func story_line(story: Dictionary, days_ago: int) -> String:
	var key := "today" if days_ago <= 0 else "yesterday" if days_ago == 1 else "earlier"
	return _told(story, key, days_ago)


## The lines of the stories (Npc `stories`, oldest first) that a villager is told on day `today`.
func story_lines(stories: Array[Dictionary], today: int) -> Array[String]:
	var lines: Array[String] = []
	for story in stories:
		lines.append(story_line(story, today - story["day"]))
	return lines


## The line a story leaves in long-term memory: "On day 4: you saw the newcomer fell 7 trees by
## Antje's house.", or "On day 4: Moiken told you that the newcomer was seen to fell 7 trees by
## Antje's house." for a story heard, or "On day 4: " and the story's own words.
func memory_line(story: Dictionary) -> String:
	return _told(story, "memory", 0)


## The words of `key` in [story] (the `heard_` ones if the story was heard) with the story's
## fields.
func _told(story: Dictionary, key: String, days_ago: int) -> String:
	var kind := "voiced_" if story["line"] != "" else "heard_" if story["how"] == HEARD else ""
	var words: String = _values["story"][kind + key]
	return (
		words
		. format(
			{
				"days": days_ago,
				"day": story["day"],
				"line": story["line"],
				"teller": str(story["told_by"]).get_slice(" ", 0),
				"deed": deed_words(story["kind"], story["count"]),
				"place": story["place"],
			}
		)
	)
