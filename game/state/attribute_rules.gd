class_name AttributeRules
extends RefCounted
## The attributes and what a level of each gives, read from data/attributes.cfg (see there for
## what each key means). `from_file` reports every key that is missing or wrong, and `is_valid`
## says whether any was.

const DEFAULT_PATH := "res://data/attributes.cfg"

## The sections that hold rules; every other section is an attribute.
const RULE_KEYS := {
	"levels": ["min", "max"],
	"effects": ["energy_per_stamina", "health_per_hp", "free_kg_per_strength"],
}
const ATTRIBUTE_KEYS: Array[String] = ["name", "description", "base"]

static var _default: AttributeRules

## {section: {key: value}}, as in the file.
var _values: Dictionary
var _problems: Array[String] = []


func _init(values: Dictionary) -> void:
	_values = values
	for section: String in RULE_KEYS:
		for key: String in RULE_KEYS[section]:
			var value: Variant = _values.get(section, {}).get(key)
			if value == null:
				_problems.append("[%s] no %s" % [section, key])
			elif not (value is float or value is int) or value <= 0:
				_problems.append("[%s] %s must be a number above 0" % [section, key])
	if attribute_ids().is_empty():
		_problems.append("no attributes")
	for attribute in attribute_ids():
		for key in ATTRIBUTE_KEYS:
			if not _values[attribute].has(key):
				_problems.append("[%s] no %s" % [attribute, key])
		if _values[attribute].has("base") and not _values[attribute]["base"] is int:
			_problems.append("[%s] base must be a whole number" % attribute)


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> AttributeRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> AttributeRules:
	var rules := AttributeRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	return _problems


func is_valid() -> bool:
	return _problems.is_empty()


## The attribute ids, in the order of the file.
func attribute_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for section: String in _values:
		if not RULE_KEYS.has(section):
			ids.append(StringName(section))
	return ids


func has_attribute(attribute: StringName) -> bool:
	return attribute_ids().has(attribute)


func attribute_name(attribute: StringName) -> String:
	return _values[str(attribute)]["name"]


func description(attribute: StringName) -> String:
	return _values[str(attribute)]["description"]


## The level a new character has.
func base_level(attribute: StringName) -> int:
	return _values[str(attribute)]["base"]


func min_level() -> int:
	return int(_values["levels"]["min"])


func max_level() -> int:
	return int(_values["levels"]["max"])


## What one level of Stamina adds to the most energy.
func energy_per_stamina() -> float:
	return float(_values["effects"]["energy_per_stamina"])


## What one level of HP adds to the most health.
func health_per_hp() -> float:
	return float(_values["effects"]["health_per_hp"])


## What one level of Strength adds to the kilograms carried before the load costs more energy.
func free_kg_per_strength() -> float:
	return float(_values["effects"]["free_kg_per_strength"])
