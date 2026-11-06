class_name EnergyRules
extends RefCounted
## The numbers of the energy system, read from data/energy.cfg (see there for what each one
## means). Rules the game can't do without are listed in REQUIRED_KEYS: `from_file` reports
## every one that is missing, and `is_valid` says whether any was. Only the lookups by id
## (`sleep_fill`, `food_restore`) may come up empty, for a bed or food that has no rule.

const DEFAULT_PATH := "res://data/energy.cfg"

const REQUIRED_KEYS := {
	"cost": ["till", "hit", "water", "plant", "pick", "mow", "dig"],
	"weight": ["free_kg", "step_kg", "extra_per_step"],
	"walk": ["slow_energy", "slow_speed", "very_slow_energy", "very_slow_speed"],
	"debuff": ["walk_speed", "energy_max", "health"],
	"bars": ["warning"],
	"signs": ["tired", "exhausted", "late_first_minute", "late_second_minute"],
}

static var _default: EnergyRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> EnergyRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> EnergyRules:
	var rules := EnergyRules.new(DataFile.read_sections(path))
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


## The energy a use of this kind costs (`till`, `hit`, `water`, `plant`, `pick`, `mow`, `dig`),
## before the weight and drain factors.
func cost_of(use_kind: StringName) -> float:
	return _value("cost", use_kind)


## How much more a use costs while carrying this many kilograms: 1 up to the free weight,
## then linearly more.
func weight_factor(kilograms: float) -> float:
	var over := maxf(0.0, kilograms - _value("weight", "free_kg"))
	return 1.0 + over / _value("weight", "step_kg") * _value("weight", "extra_per_step")


## The energy and health that sleeping in a bed of this object type fills up to; 0 for a bed
## with no rule.
func sleep_fill(bed_type: StringName) -> float:
	return float(_values.get("sleep", {}).get(str(bed_type), 0.0))


func is_food(item: StringName) -> bool:
	return _values.get("food", {}).has(str(item))


func food_restore(item: StringName) -> float:
	return float(_values.get("food", {}).get(str(item), 0.0))


## The fraction of full walking speed that this much energy allows.
func walk_factor(energy: float) -> float:
	if energy < _value("walk", "very_slow_energy"):
		return _value("walk", "very_slow_speed")
	if energy <= _value("walk", "slow_energy"):
		return _value("walk", "slow_speed")
	return 1.0


func debuff_walk_factor() -> float:
	return _value("debuff", "walk_speed")


func debuff_energy_max() -> float:
	return _value("debuff", "energy_max")


func debuff_health() -> float:
	return _value("debuff", "health")


func warning_level() -> float:
	return _value("bars", "warning")


## At this much energy or less the player shows the first signs of tiredness.
func tired_level() -> float:
	return _value("signs", "tired")


## At this much energy or less the signs are stronger.
func exhausted_level() -> float:
	return _value("signs", "exhausted")


## The minutes after midnight at which a player still awake is warned (see TirednessSigns).
func late_warning_minutes() -> Array[int]:
	return [int(_value("signs", "late_first_minute")), int(_value("signs", "late_second_minute"))]


## A required rule; `from_file` has reported it already if it is missing.
func _value(section: String, key: StringName) -> float:
	return float(_values.get(section, {}).get(str(key), 0.0))
