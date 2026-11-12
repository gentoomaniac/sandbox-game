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
	"ground_mix": BOUNDARIES,
	"litter": ["from_day", "full_day", "thins_day", "gone_day"],
	"foliage": BOUNDARIES + [&"leaf_out_span"],
	"snow":
	[
		"snowfall_per_hour",
		"melt_per_degree_hour",
		"sun_melt_gain",
		"counted_from_day",
		"full_thaw_at_temperature"
	],
	"cover":
	[
		"crown_radius",
		"leaf_open",
		"leaf_field",
		"leaf_path",
		"snow_under_crown",
		"snow_lee",
		"lee_reach",
		"snow_path",
		"melt_open",
		"melt_path",
		"melt_under_crown",
		"thaw_gain",
		"object_snow_gain",
		"frost_under_crown"
	],
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
	var rules := SeasonRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing, as "[section] what".
func problems() -> Array[String]:
	var missing: Array[String] = []
	for section: String in REQUIRED_KEYS:
		for key: String in REQUIRED_KEYS[section]:
			if not _values.get(section, {}).has(key):
				missing.append("[%s] no %s" % [section, key])
	return missing


func is_valid() -> bool:
	return problems().is_empty()


## A required number; `from_file` has reported it already if it is missing.
func value(section: String, key: String) -> float:
	return float(_values.get(section, {}).get(key, 0.0))


## A blend window: Vector2(first day, last day of the year).
func window(section: String, boundary: StringName) -> Vector2:
	return _values.get(section, {}).get(boundary, Vector2.ZERO)
