class_name SeasonRules
extends RefCounted
## The numbers of the seasonal look, read from data/seasons.cfg (see there for what each one
## means). `from_file` reports every required key that is missing, and `is_valid` says whether
## any was.

const DEFAULT_PATH := "res://data/seasons.cfg"

## The boundaries of a blend window, in the order of the year, as the keys of the sections
## [ground] and [foliage].
const BOUNDARIES: Array[StringName] = [
	&"bare_to_spring", &"spring_to_summer", &"summer_to_autumn", &"autumn_to_bare"
]
const REQUIRED_KEYS := {
	"ground": BOUNDARIES,
	"foliage": BOUNDARIES,
	"snow": ["snowfall_per_hour", "melt_per_degree_hour", "sun_melt_gain", "counted_from_day"],
	"frost": ["full_at_temperature"],
}

static var _default: SeasonRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> SeasonRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> SeasonRules:
	var file := ConfigFile.new()
	var error := file.load(path)
	if error != OK:
		push_error("Can't read %s: %s" % [path, error_string(error)])
	var values := {}
	for section in file.get_sections():
		values[section] = {}
		for key in file.get_section_keys(section):
			values[section][key] = file.get_value(section, key)
	var rules := SeasonRules.new(values)
	for missing in rules.missing_keys():
		push_error("%s: no %s" % [path, missing])
	return rules


## The required keys the rules lack, as "[section] key".
func missing_keys() -> Array[String]:
	var missing: Array[String] = []
	for section: String in REQUIRED_KEYS:
		for key: String in REQUIRED_KEYS[section]:
			if not _values.get(section, {}).has(key):
				missing.append("[%s] %s" % [section, key])
	return missing


func is_valid() -> bool:
	return missing_keys().is_empty()


## A required number; `from_file` has reported it already if it is missing.
func value(section: String, key: String) -> float:
	return float(_values.get(section, {}).get(key, 0.0))


## A blend window: Vector2(first day, last day of the year).
func window(section: String, boundary: StringName) -> Vector2:
	return _values.get(section, {}).get(boundary, Vector2.ZERO)
