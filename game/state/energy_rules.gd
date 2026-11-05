class_name EnergyRules
extends RefCounted
## The numbers of the energy system, read from data/energy.cfg (see there for what each one
## means). A rule that is missing from the data is reported, and counts as 0.

const DEFAULT_PATH := "res://data/energy.cfg"

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
	var file := ConfigFile.new()
	var error := file.load(path)
	if error != OK:
		push_error("Can't read %s: %s" % [path, error_string(error)])
	var values := {}
	for section in file.get_sections():
		values[section] = {}
		for key in file.get_section_keys(section):
			values[section][key] = file.get_value(section, key)
	return EnergyRules.new(values)


## The energy a use of this kind costs (`till`, `hit`, `water`, `plant`, `pick`, `eat`), before
## the weight and drain factors.
func cost_of(use_kind: StringName) -> float:
	return _value("cost", use_kind)


## How much more a use costs while carrying this many kilograms: 1 up to the free weight,
## then linearly more.
func weight_factor(kilograms: float) -> float:
	var over := maxf(0.0, kilograms - _value("weight", "free_kg"))
	return 1.0 + over / _value("weight", "step_kg") * _value("weight", "extra_per_step")


## The energy and health that sleeping in a bed of this object type fills up to.
func sleep_fill(bed_type: StringName) -> float:
	return _value("sleep", bed_type)


func is_food(item: StringName) -> bool:
	return _values.get("food", {}).has(str(item))


func food_restore(item: StringName) -> float:
	return _value("food", item)


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


func _value(section: String, key: StringName) -> float:
	var value: Variant = _values.get(section, {}).get(str(key))
	if value == null:
		push_error("Energy rules: no [%s] %s" % [section, key])
		return 0.0
	return float(value)
