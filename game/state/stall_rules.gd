class_name StallRules
extends RefCounted
## What the villagers do at the player's sales cart, read from data/stall.cfg (see there for what
## each key means). `from_file` reports everything wrong with the file, and `is_valid` says
## whether anything was.

const DEFAULT_PATH := "res://data/stall.cfg"
## What each section has: its keys and their kinds.
const WHOLE := &"whole"
const NUMBER := &"number"
const LEVEL_LIST := &"level_list"
const KEYS := {
	"visits": {"per_day": WHOLE, "rain_hours_limit": NUMBER},
	"chance": {"base_percent": WHOLE},
	"buy": {"most_things": WHOLE, "liked_weight": WHOLE},
	"friendship": {"chance_percent": LEVEL_LIST, "limit_percent": LEVEL_LIST},
	"contact": {"sale_points": WHOLE, "needed_sale_points": WHOLE},
}

static var _default: StallRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> StallRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> StallRules:
	var rules := StallRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	for section: String in KEYS:
		if not _values.has(section):
			found.append("[%s] is missing" % section)
			continue
		for key: String in KEYS[section]:
			var value: Variant = _values[section].get(key)
			if not _is_valid(value, KEYS[section][key]):
				found.append("[%s] %s is not %s" % [section, key, _kind_text(KEYS[section][key])])
	for section: String in _values:
		if not KEYS.has(section):
			found.append("[%s] is not a section of the file" % section)
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The value of a key, a whole number or a number (see KEYS).
func value(section: String, key: String) -> Variant:
	return _values[section][key]


## How likely a villager of the friendship `level` (1 to 10) comes by, as a percent of the base
## chance.
func chance_percent(level: int) -> int:
	return _values["friendship"]["chance_percent"][level - 1]


## The most a villager of the friendship `level` pays for a good, as a percent of its worth.
func limit_percent(level: int) -> int:
	return _values["friendship"]["limit_percent"][level - 1]


static func _is_valid(value: Variant, kind: StringName) -> bool:
	match kind:
		WHOLE:
			return value is int and value >= 0
		NUMBER:
			return (value is int or value is float) and value >= 0
	return (
		value is Array
		and value.size() == FriendshipRules.LEVEL_COUNT
		and value.all(func(entry: Variant) -> bool: return entry is int and entry >= 0)
	)


static func _kind_text(kind: StringName) -> String:
	match kind:
		WHOLE:
			return "a whole number from 0"
		NUMBER:
			return "a number from 0"
	return "a list of %d whole numbers from 0" % FriendshipRules.LEVEL_COUNT
