class_name PathRules
extends RefCounted
## How grass wears to a desire path and grows back, read from data/paths.cfg (see there for
## what each number means). `from_file` reports every key that is missing or out of range, and
## `is_valid` says whether any was.

## How worn a tile looks, by its steps of wear (see `stage_of`).
enum Stage { UNWORN, TRODDEN, PATH }

const DEFAULT_PATH := "res://data/paths.cfg"

const REQUIRED_KEYS := {
	"wear":
	["trodden_from", "path_from", "most", "regrowth_per_night", "animal_step", "villager_step"],
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
	if not (0.0 < trodden_from() and trodden_from() < path_from() and path_from() <= most()):
		found.append("[wear] needs 0 < trodden_from < path_from <= most")
	if regrowth_per_night() <= 0.0:
		found.append("[wear] regrowth_per_night must be above 0")
	if animal_step() < 0.0:
		found.append("[wear] animal_step must not be below 0")
	if villager_step() < 0.0:
		found.append("[wear] villager_step must not be below 0")
	return found


func is_valid() -> bool:
	return problems().is_empty()


func trodden_from() -> float:
	return _value("trodden_from")


func path_from() -> float:
	return _value("path_from")


## The most steps of wear a tile counts.
func most() -> float:
	return _value("most")


func regrowth_per_night() -> float:
	return _value("regrowth_per_night")


## The steps of wear a farm animal leaves on a tile it walks onto; 0 if animals make no tracks.
func animal_step() -> float:
	return _value("animal_step")


## The steps of wear a villager leaves on a tile it walks onto; 0 if villagers make no tracks.
func villager_step() -> float:
	return _value("villager_step")


## How a tile with this many steps of wear looks.
func stage_of(steps: float) -> Stage:
	if steps >= path_from():
		return Stage.PATH
	if steps >= trodden_from():
		return Stage.TRODDEN
	return Stage.UNWORN


func _value(key: String) -> float:
	return float(_values["wear"][key])
