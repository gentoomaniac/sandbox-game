class_name PathRules
extends RefCounted
## How grass wears to a desire path and grows back, and what the rain makes of worn ground, read
## from data/paths.cfg (see there for what each number means). `from_file` reports every key that
## is missing or out of range, and `is_valid` says whether any was.

## How worn a tile looks, by its days of wear (see `stage_of`).
enum Stage { UNWORN, TRODDEN, PATH }

const DEFAULT_PATH := "res://data/paths.cfg"

const REQUIRED_KEYS := {
	"wear":
	[
		"busy_steps",
		"trodden_after_days",
		"path_after_days",
		"most_days",
		"quiet_day_loss",
		"animal_step",
		"villager_step",
	],
	"mud": ["soaked_by", "window_hours", "walk_factor"],
}

static var _default: PathRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> PathRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> PathRules:
	var rules := PathRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	for section: String in REQUIRED_KEYS:
		for key: String in REQUIRED_KEYS[section]:
			if not _values.get(section, {}).has(key):
				found.append("[%s] no %s" % [section, key])
	if not found.is_empty():
		return found
	if busy_steps() <= 0.0:
		found.append("[wear] busy_steps must be above 0")
	if not (
		0 < trodden_after_days()
		and trodden_after_days() < path_after_days()
		and path_after_days() <= most_days()
	):
		found.append("[wear] needs 0 < trodden_after_days < path_after_days <= most_days")
	if quiet_day_loss() < 1:
		found.append("[wear] quiet_day_loss must be at least 1")
	if animal_step() < 0.0:
		found.append("[wear] animal_step must not be below 0")
	if villager_step() < 0.0:
		found.append("[wear] villager_step must not be below 0")
	if soaked_by() <= 0.0:
		found.append("[mud] soaked_by must be above 0")
	if window_hours() < 1:
		found.append("[mud] window_hours must be at least 1")
	if not (0.0 < walk_factor() and walk_factor() <= 1.0):
		found.append("[mud] walk_factor must be above 0 and at most 1")
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The steps a tile needs in a day for the day to be busy.
func busy_steps() -> float:
	return _value("wear", "busy_steps")


func trodden_after_days() -> int:
	return int(_value("wear", "trodden_after_days"))


func path_after_days() -> int:
	return int(_value("wear", "path_after_days"))


## The most days of wear a tile counts.
func most_days() -> int:
	return int(_value("wear", "most_days"))


## The days of wear a quiet day takes off a tile.
func quiet_day_loss() -> int:
	return int(_value("wear", "quiet_day_loss"))


## The steps of wear a farm animal leaves on a tile it walks onto; 0 if animals make no tracks.
func animal_step() -> float:
	return _value("wear", "animal_step")


## The steps of wear a villager leaves on a tile it walks onto; 0 if villagers make no tracks.
func villager_step() -> float:
	return _value("wear", "villager_step")


## How a tile with this many days of wear looks.
func stage_of(days: int) -> Stage:
	if days >= path_after_days():
		return Stage.PATH
	if days >= trodden_after_days():
		return Stage.TRODDEN
	return Stage.UNWORN


## The rain (the rain of each hour added up) that makes worn ground mud when it falls within
## `window_hours`.
func soaked_by() -> float:
	return _value("mud", "soaked_by")


func window_hours() -> int:
	return int(_value("mud", "window_hours"))


## The fraction of their speed that the player walks at on mud.
func walk_factor() -> float:
	return _value("mud", "walk_factor")


func _value(section: String, key: String) -> float:
	return float(_values[section][key])
