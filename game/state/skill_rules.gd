class_name SkillRules
extends RefCounted
## The skills and how they grow, read from data/skills.cfg (see there for what each key means).
## `from_file` reports every key that is missing or wrong, and `is_valid` says whether any was.

const DEFAULT_PATH := "res://data/skills.cfg"

## The sections that hold rules; every other section is a skill.
const RULE_KEYS := {
	"cap": ["skill", "total"],
	"gain": ["at_level", "trivial_above"],
}
const SKILL_KEYS: Array[String] = ["name", "description"]

static var _default: SkillRules

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
	if skill_ids().is_empty():
		_problems.append("no skills")
	for skill in skill_ids():
		for key in SKILL_KEYS:
			if not _values[skill].has(key):
				_problems.append("[%s] no %s" % [skill, key])


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> SkillRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> SkillRules:
	var rules := SkillRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	return _problems


func is_valid() -> bool:
	return _problems.is_empty()


## The skill ids, in the order of the file.
func skill_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for section: String in _values:
		if not RULE_KEYS.has(section):
			ids.append(StringName(section))
	return ids


func has_skill(skill: StringName) -> bool:
	return skill_ids().has(skill)


func skill_name(skill: StringName) -> String:
	return _values[str(skill)]["name"]


func description(skill: StringName) -> String:
	return _values[str(skill)]["description"]


## The most points one skill can have.
func skill_cap() -> float:
	return float(_values["cap"]["skill"])


## The most points all skills together can have.
func total_cap() -> float:
	return float(_values["cap"]["total"])


## How far above a recipe's level a skill still learns from it.
func trivial_above() -> float:
	return float(_values["gain"]["trivial_above"])


## What one craft of a recipe of `level` teaches a skill that has `points`: the full gain at or
## below the level, falling evenly to nothing at `trivial_above` points over it.
func gain(points: float, level: float) -> float:
	var full := float(_values["gain"]["at_level"])
	var trivial_above := float(_values["gain"]["trivial_above"])
	return full * maxf(1.0 - maxf(points - level, 0.0) / trivial_above, 0.0)
