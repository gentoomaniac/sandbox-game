class_name LandscapeRules
extends RefCounted
## The numbers of the marsh, the dykes and the coast,
## read from data/landscape.cfg (see there for what each one means). `from_file` reports every key
## that is missing or out of range, and `is_valid` says whether any was.

const DEFAULT_PATH := "res://data/landscape.cfg"

const REQUIRED_KEYS := {
	"marsh": ["reach"],
	"dykes": ["stretch_above"],
	"coast": ["line_x", "wander", "salt_marsh_width", "salt_marsh_wander", "flats_width"],
	"tideways": ["spacing", "meander", "widening", "widest"],
	"warften": ["spacing", "chance", "out"],
	"ewers": ["spacing", "chance", "out_from", "out_to"],
}
static var _default: LandscapeRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> LandscapeRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> LandscapeRules:
	var rules := LandscapeRules.new(DataFile.read_sections(path))
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
	var tideway_band := 2.0 * value("tideways", "meander") + value("tideways", "widest")
	if tideway_band >= value("tideways", "spacing"):
		found.append("[tideways] twice the meander and the widest must be less than the spacing")
	return found


func is_valid() -> bool:
	return problems().is_empty()


## A number of the file, e.g. `value("coast", "line_x")`.
func value(section: String, key: String) -> float:
	return float(_values[section][key])
