class_name CropRules
extends RefCounted
## The crops and the farming rules, read from data/crops.cfg (see there for what each key
## means; the wild reeds have a section of their own, no crop). `from_file` reports every
## required key that is missing, and `is_valid` says whether any was. WorldObjectTypes and
## ItemTypes build the crop object types and the seed and produce items from `default_rules`;
## the art sheet of every crop is loaded from its `sheet`.

const DEFAULT_PATH := "res://data/crops.cfg"
## The section with the rules that are not a crop's.
const FARMING := "farming"
## The section with the growing needs of the wild reeds, which are not a crop.
const REEDS := "reeds"
## Growth stages of every crop: its sheet has these and then the dead stage.
const STAGES := 4

const REQUIRED_CROP_KEYS: Array[String] = [
	"name",
	"seed_name",
	"description",
	"sheet",
	"seed",
	"produce",
	"seed_weight",
	"produce_weight",
	"yield",
	"seed_chance",
	"regrow_stage",
	"ripe_wait_factor",
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
## Keys of a crop that it may leave out, to get the value of the [farming] section.
const HARVEST_CHANCE_KEYS: Array[String] = ["poor_harvest_chance", "good_harvest_chance"]
const REQUIRED_FARMING_KEYS: Array[String] = [
	"default_moisture",
	"poor_harvest_chance",
	"good_harvest_chance",
	"rain_wets",
	"drying_base",
	"drying_per_degree",
	"drying_per_sun_hour",
	"drying_per_wind",
	"good_day_score",
	"fallow_weedy_days",
	"fallow_grass_days",
	"fallow_rests_in_winter",
]
const REQUIRED_REEDS_KEYS: Array[String] = [
	"regrow_growth",
	"temperature_min",
	"temperature_best",
	"temperature_max",
	"sunlight_min",
	"sunlight_best",
]

static var _default: CropRules

## {crop id: {key: value}}, in the order of the file.
var _crops: Dictionary
var _farming: Dictionary
var _reeds: Dictionary
var _problems: Array[String] = []


func _init(crops: Dictionary, farming: Dictionary, reeds: Dictionary) -> void:
	_crops = crops
	_farming = farming
	_reeds = reeds
	for key in REQUIRED_FARMING_KEYS:
		if not _farming.has(key):
			_problems.append("[%s] no %s" % [FARMING, key])
	for key in REQUIRED_REEDS_KEYS:
		if not _reeds.has(key):
			_problems.append("[%s] no %s" % [REEDS, key])
	for crop_id: String in _crops:
		for key in HARVEST_CHANCE_KEYS:
			if not _crops[crop_id].has(key) and _farming.has(key):
				_crops[crop_id][key] = _farming[key]
		for key in REQUIRED_CROP_KEYS:
			if not _crops[crop_id].has(key):
				_problems.append("[%s] no %s" % [crop_id, key])
		_check_harvest(crop_id, _crops[crop_id])
		if _crops[crop_id].has("regrow_stage"):
			var regrow_stage: int = _crops[crop_id]["regrow_stage"]
			if regrow_stage < 0 or regrow_stage >= STAGES:
				_problems.append("[%s] regrow_stage must be 0 up to %d" % [crop_id, STAGES - 1])


func _check_harvest(crop_id: String, values: Dictionary) -> void:
	for key in ["yield", "seed_chance"] + HARVEST_CHANCE_KEYS:
		if not values.has(key):
			return
	if values["yield"] < 1:
		_problems.append("[%s] yield must be 1 or more" % crop_id)
	for key in HARVEST_CHANCE_KEYS + ["seed_chance"]:
		if values[key] < 0.0 or values[key] > 1.0:
			_problems.append("[%s] %s must be 0 to 1" % [crop_id, key])
	if values["poor_harvest_chance"] + values["good_harvest_chance"] > 1.0:
		_problems.append("[%s] the two harvest chances must add up to 1 at most" % crop_id)


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> CropRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> CropRules:
	var crops := DataFile.read_sections(path)
	var farming: Dictionary = crops.get(FARMING, {})
	var reeds: Dictionary = crops.get(REEDS, {})
	crops.erase(FARMING)
	crops.erase(REEDS)
	var rules := CropRules.new(crops, farming, reeds)
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


## The growing needs of the wild reeds, as in the file (the [reeds] section).
func reeds() -> Dictionary:
	return _reeds
