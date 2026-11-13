class_name CropRaidRules
extends RefCounted
## What crows do to crops, read from data/crows.cfg (see there for what each key means). `from_file`
## reports every missing key, and `is_valid` says whether any was.

const DEFAULT_PATH := "res://data/crows.cfg"
const SECTION := "raids"
const KEYS := [
	"player_tiles",
	"hour_chance",
	"reach_tiles",
	"crops_per_raid",
	"stage_chances",
	"whole_up_to_stage",
	"max_plants_per_day",
	"max_items_per_day",
	"sown_boost_per_crop",
	"sown_boost_max",
	"sown_radius_tiles",
	"scarecrow_radius_tiles",
	"scarecrow_fresh_days",
	"scarecrow_fade_days",
	"scarecrow_floor",
]

static var _default: CropRaidRules

## {key: value}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> CropRaidRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> CropRaidRules:
	var rules := CropRaidRules.new(DataFile.read_sections(path).get(SECTION, {}))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[raids] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	for key: String in KEYS:
		if not _values.has(key):
			found.append("[%s] no %s" % [SECTION, key])
	var chances: Variant = _values.get("stage_chances", [])
	if not chances is Array or chances.size() != CropRules.STAGES:
		found.append(
			(
				"[%s] stage_chances needs one chance for each of the %d stages"
				% [SECTION, CropRules.STAGES]
			)
		)
	return found


func is_valid() -> bool:
	return problems().is_empty()


## A number of the file.
func value(key: String) -> float:
	return float(_values[key])


## How strongly a scarecrow that has stood `age_days` days guards, from 0 to 1: fully while it is
## fresh, then less and less as the crows get used to it, down to the floor.
func scarecrow_strength(age_days: int) -> float:
	var fade := clampf(
		float(age_days - value("scarecrow_fresh_days")) / value("scarecrow_fade_days"), 0.0, 1.0
	)
	return lerpf(1.0, value("scarecrow_floor"), fade)


## The chance that a crop at a growth stage loses something when a flock tries it.
func stage_chance(stage: int) -> float:
	return float(_values["stage_chances"][stage])
