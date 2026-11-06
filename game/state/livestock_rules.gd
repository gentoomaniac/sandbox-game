class_name LivestockRules
extends RefCounted
## How the farm animals look and behave: the numbers of data/livestock.cfg (see there for what
## each one means). `from_file` reports every missing or malformed key, and `is_valid` says
## whether there was one.

const DEFAULT_PATH := "res://data/livestock.cfg"

const COW := &"cow"
const SHEEP := &"sheep"
const CHICKEN := &"chicken"
const RABBIT := &"rabbit"
const SPECIES: Array[StringName] = [COW, SHEEP, CHICKEN, RABBIT]

const GENERAL_KEYS := ["calm_extra_tiles", "bedtime_spread_minutes"]
const SPECIES_KEYS := [
	"looks",
	"look_weights",
	"tints",
	"activity_weights",
	"idle_seconds",
	"walk_seconds",
	"graze_seconds",
	"run_seconds",
	"walk_speed",
	"body_tiles",
	"flee_tiles",
	"run_speed",
	"sleep_minutes",
	"wake_minutes",
]
## The activities `activity_weights` weighs, in its order.
const CHOSEN_ACTIVITIES: Array[FarmAnimal.Activity] = [
	FarmAnimal.Activity.IDLE,
	FarmAnimal.Activity.WALK,
	FarmAnimal.Activity.GRAZE,
	FarmAnimal.Activity.RUN,
]
## The key of how long each chosen activity lasts.
const SECONDS_KEYS := {
	FarmAnimal.Activity.IDLE: "idle_seconds",
	FarmAnimal.Activity.WALK: "walk_seconds",
	FarmAnimal.Activity.GRAZE: "graze_seconds",
	FarmAnimal.Activity.RUN: "run_seconds",
}

static var _default: LivestockRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> LivestockRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> LivestockRules:
	var rules := LivestockRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or malformed, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	for key: String in GENERAL_KEYS:
		if not _values.get("general", {}).has(key):
			found.append("[general] no %s" % key)
	for species in SPECIES:
		var values: Dictionary = _values.get(String(species), {})
		var missing := SPECIES_KEYS.filter(func(key: String) -> bool: return not values.has(key))
		for key: String in missing:
			found.append("[%s] no %s" % [species, key])
		if not missing.is_empty():
			continue
		if values["looks"].is_empty() or values["looks"].size() != values["look_weights"].size():
			found.append("[%s] looks and look_weights differ in length or are empty" % species)
		var tints: Array = values["tints"]
		if (
			tints.is_empty()
			or not tints.all(func(tint: String) -> bool: return Color.html_is_valid(tint))
		):
			found.append("[%s] tints needs one colour or more, as hex" % species)
		if values["activity_weights"].size() != CHOSEN_ACTIVITIES.size():
			found.append("[%s] activity_weights needs idle, walk, graze and run" % species)
		for key: String in SECONDS_KEYS.values():
			if values[key].size() != 2 or values[key][0] > values[key][1]:
				found.append("[%s] %s needs [shortest, longest]" % [species, key])
	return found


func is_valid() -> bool:
	return problems().is_empty()


func general(key: String) -> float:
	return float(_values["general"][key])


func looks(species: StringName) -> Array:
	return _value(species, "looks")


## A look of a species, drawn by its `look_weights`.
func pick_look(species: StringName, rng: RandomNumberGenerator) -> StringName:
	var weights := PackedFloat32Array(_value(species, "look_weights"))
	return StringName(looks(species)[rng.rand_weighted(weights)])


## One of a species' tints, each as likely.
func pick_tint(species: StringName, rng: RandomNumberGenerator) -> Color:
	var tints: Array = _value(species, "tints")
	return Color.html(tints[rng.randi() % tints.size()])


## What an awake animal does next, drawn by its `activity_weights`.
func pick_activity(species: StringName, rng: RandomNumberGenerator) -> FarmAnimal.Activity:
	var weights := PackedFloat32Array(_value(species, "activity_weights"))
	return CHOSEN_ACTIVITIES[rng.rand_weighted(weights)]


## How long a chosen activity lasts this time, in seconds.
func pick_seconds(
	species: StringName, activity: FarmAnimal.Activity, rng: RandomNumberGenerator
) -> float:
	var range_seconds: Array = _value(species, SECONDS_KEYS[activity])
	return rng.randf_range(range_seconds[0], range_seconds[1])


func walk_speed(species: StringName) -> float:
	return _value(species, "walk_speed")


func body_tiles(species: StringName) -> float:
	return _value(species, "body_tiles")


func flee_tiles(species: StringName) -> float:
	return _value(species, "flee_tiles")


func run_speed(species: StringName) -> float:
	return _value(species, "run_speed")


func sleep_minutes(species: StringName) -> float:
	return _value(species, "sleep_minutes")


func wake_minutes(species: StringName) -> float:
	return _value(species, "wake_minutes")


func _value(species: StringName, key: String) -> Variant:
	return _values[String(species)][key]
