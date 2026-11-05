class_name CropRules
extends RefCounted
## The crops and the farming rules, read from data/crops.cfg (see there for what each key
## means). `from_file` reports every required key that is missing, and `is_valid` says whether
## any was. WorldObjectTypes and ItemTypes build the crop object types and the seed and
## produce items from `default_rules`; the art sheet of every crop is loaded from its `sheet`.

const DEFAULT_PATH := "res://data/crops.cfg"
## The section with the rules that are not a crop's.
const FARMING := "farming"
## Growth stages of every crop: its sheet has these and then the dead stage.
const STAGES := 4

const REQUIRED_CROP_KEYS: Array[String] = [
	"name",
	"seed_name",
	"sheet",
	"seed",
	"produce",
	"seed_weight",
	"produce_weight",
	"yield",
	"regrow_stage",
	"growth_per_stage",
	"damage_per_bad_day",
	"heal_per_good_day",
	"temperature_min",
	"temperature_best",
	"temperature_max",
	"sunlight_min",
	"sunlight_best",
	"moisture_min",
	"moisture_best",
	"wind_max",
]
const REQUIRED_FARMING_KEYS: Array[String] = [
	"default_moisture",
	"rain_wets",
	"drying_base",
	"drying_per_degree",
	"drying_per_sun_hour",
	"drying_per_wind",
	"good_day_score",
]

static var _default: CropRules

## {crop id: {key: value}}, in the order of the file.
var _crops: Dictionary
var _farming: Dictionary
var _problems: Array[String] = []


func _init(crops: Dictionary, farming: Dictionary) -> void:
	_crops = crops
	_farming = farming
	for key in REQUIRED_FARMING_KEYS:
		if not _farming.has(key):
			_problems.append("[%s] no %s" % [FARMING, key])
	for crop_id: String in _crops:
		for key in REQUIRED_CROP_KEYS:
			if not _crops[crop_id].has(key):
				_problems.append("[%s] no %s" % [crop_id, key])
		if _crops[crop_id].has("regrow_stage"):
			var regrow_stage: int = _crops[crop_id]["regrow_stage"]
			if regrow_stage < 0 or regrow_stage >= STAGES:
				_problems.append("[%s] regrow_stage must be 0 up to %d" % [crop_id, STAGES - 1])


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> CropRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> CropRules:
	var file := ConfigFile.new()
	var error := file.load(path)
	if error != OK:
		push_error("Can't read %s: %s" % [path, error_string(error)])
	var crops := {}
	var farming := {}
	for section in file.get_sections():
		var values := {}
		for key in file.get_section_keys(section):
			values[key] = file.get_value(section, key)
		if section == FARMING:
			farming = values
		else:
			crops[section] = values
	var rules := CropRules.new(crops, farming)
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	return _problems


func is_valid() -> bool:
	return _problems.is_empty()


## The crop ids, in the order of the file.
func crop_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for crop_id: String in _crops:
		ids.append(StringName(crop_id))
	return ids


## One crop's values, as in the file.
func crop(crop_id: StringName) -> Dictionary:
	return _crops[str(crop_id)]


## A value of the farming rules (the [farming] section).
func farming(key: String) -> float:
	return float(_farming.get(key, 0.0))
