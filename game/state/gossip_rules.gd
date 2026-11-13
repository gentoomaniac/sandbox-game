class_name GossipRules
extends RefCounted
## The words and numbers of the deed log, read from data/gossip.cfg (see there for what each key
## means): how far a villager sees, how long a deed is kept, the words of a deed, of a place and of
## the story a villager is told, which names the teller if it was heard.

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
	"places": ["house"],
	"story":
	[
		"today",
		"yesterday",
		"earlier",
		"memory",
		"heard_today",
		"heard_yesterday",
		"heard_earlier",
		"heard_memory"
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


## What the villagers who saw a deed of this kind think more (or less) of the player.
func opinion_change(kind: StringName) -> int:
	return int(_values[str(kind)]["change"])


## The deed in words, to follow "the newcomer": "fell 7 trees".
func deed_words(kind: StringName, count: int) -> String:
	var words: String = _values[str(kind)]["one" if count == 1 else "many"]
	return words.format({"count": count})


## "by Antje's house", for the villager with this first name.
func house_place(first_name: String) -> String:
	return str(_values["places"]["house"]).format({"name": first_name})


## "out on the marsh": where there is no house in reach, by the ground.
func ground_place(terrain: Tile.Terrain) -> String:
	return _values["places"][Tile.Terrain.keys()[terrain].to_lower()]


## What a villager is told of a story (a deed, see DeedLog) `days_ago` days after it: "Today you
## saw the newcomer fell 7 trees by Antje's house.", or, if they heard it, "Today Moiken told you
## that the newcomer was seen to fell 7 trees by Antje's house."
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
## Antje's house." for a story heard.
func memory_line(story: Dictionary) -> String:
	return _told(story, "memory", 0)


## The words of `key` in [story] (the `heard_` ones if the story was heard) with the story's
## fields.
func _told(story: Dictionary, key: String, days_ago: int) -> String:
	var words: String = _values["story"][("heard_" + key) if story["how"] == HEARD else key]
	return (
		words
		. format(
			{
				"days": days_ago,
				"day": story["day"],
				"teller": str(story["told_by"]).get_slice(" ", 0),
				"deed": deed_words(story["kind"], story["count"]),
				"place": story["place"],
			}
		)
	)
