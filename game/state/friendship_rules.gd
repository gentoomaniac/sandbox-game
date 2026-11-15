class_name FriendshipRules
extends RefCounted
## What a villager's opinion of the player, in points, means: the ten levels of friendship, read
## from data/friendship.cfg (see there, and design/villagers/relationships.md). A level is a range
## of points, so the points are all a villager keeps.

const DEFAULT_PATH := "res://data/friendship.cfg"

const LEVEL_COUNT := 10
## What binds a villager to the player besides friendship; only `none` is built (courting and
## marriage come with their own design, see design/villagers/relationships.md).
const BOND_NONE := &"none"
const BONDS: Array[StringName] = [BOND_NONE]
const MOODS: Array[String] = ["cold", "neutral", "warm"]
## Where an entry of a level is in its value: [name, first point, mood].
const NAME := 0
const FIRST_POINT := 1
const MOOD := 2

static var _default: FriendshipRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> FriendshipRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> FriendshipRules:
	var rules := FriendshipRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what". The values are only checked once every key is
## there.
func problems() -> Array[String]:
	var bad: Array[String] = []
	var levels: Dictionary = _values.get("levels", {})
	for level in range(1, LEVEL_COUNT + 1):
		var entry: Variant = levels.get(_level_key(level))
		var is_entry: bool = (
			entry is Array
			and entry.size() == 3
			and entry[NAME] is String
			and entry[FIRST_POINT] is int
			and entry[MOOD] is String
		)
		if not is_entry:
			bad.append("[levels] %s must be [name, first point, mood]" % _level_key(level))
	if not bad.is_empty():
		return bad
	for section_and_key in [
		["caps", "action_daily_cap_points"],
		["gifts", "liked_points"],
		["gifts", "neutral_points"],
		["gifts", "disliked_points"],
	]:
		if not _values.get(section_and_key[0], {}).get(section_and_key[1]) is int:
			bad.append("[%s] %s must be a whole number" % section_and_key)
	if not bad.is_empty():
		return bad
	if levels.size() != LEVEL_COUNT:
		bad.append("[levels] must have the levels 1 to %d and no others" % LEVEL_COUNT)
	for level in range(1, LEVEL_COUNT + 1):
		if not MOODS.has(mood_of_level(level)):
			bad.append("[levels] %s has the mood %s" % [_level_key(level), mood_of_level(level)])
		if level > 1 and first_point_of(level) <= first_point_of(level - 1):
			bad.append("[levels] %s must start above the level before" % _level_key(level))
	return bad


func is_valid() -> bool:
	return problems().is_empty()


## What is wrong with the lists of the items that `where` (a villager or a set of trades) is glad
## and sorry to be given: each a list of items of the game, and no item in both.
static func gift_taste_problems(where: String, liked: Variant, disliked: Variant) -> Array[String]:
	var bad: Array[String] = []
	for entry in [["gifts_liked", liked], ["gifts_disliked", disliked]]:
		var list: Variant = entry[1]
		if not (list is Array and list.all(_is_item)):
			bad.append("%s %s is not a list of items of the game" % [where, entry[0]])
	if bad.is_empty() and liked.any(func(item: String) -> bool: return item in disliked):
		bad.append("%s likes and dislikes the same gift" % where)
	return bad


static func _is_item(value: Variant) -> bool:
	return value is String and ItemTypes.TYPES.has(StringName(value))


## The level (1 to 10) of an opinion in points; one below the first level's start is level 1.
func level_of(points: int) -> int:
	var level := 1
	while level < LEVEL_COUNT and points >= first_point_of(level + 1):
		level += 1
	return level


func level_name(level: int) -> String:
	return _entry(level)[NAME]


## The mood (`cold`, `neutral` or `warm`) of a level.
func mood_of_level(level: int) -> StringName:
	return StringName(_entry(level)[MOOD])


## The mood of an opinion in points, which the bubbles of a villager follow.
func mood_of(points: int) -> StringName:
	return mood_of_level(level_of(points))


## The lowest opinion, in points, that is of this level.
func first_point_of(level: int) -> int:
	return _entry(level)[FIRST_POINT]


## The most points the player's actions move a villager's opinion in a day, up or down.
func action_daily_cap() -> int:
	return _values["caps"]["action_daily_cap_points"]


## What a gift of this taste (`liked`, `neutral` or `disliked`) moves the opinion by, in points.
func gift_points(taste: StringName) -> int:
	return _values["gifts"]["%s_points" % taste]


func _entry(level: int) -> Array:
	assert(level >= 1 and level <= LEVEL_COUNT, "A level is 1 to %d" % LEVEL_COUNT)
	return _values["levels"][_level_key(level)]


static func _level_key(level: int) -> String:
	return "level_%d" % level
