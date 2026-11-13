class_name ToolGradeRules
extends RefCounted
## The grades every tool comes in (task 207): data/tools.cfg, one section per grade from the worst
## to the best (see there for what each number means). `from_file` reports every missing key, and
## `is_valid` says whether there was one.

const DEFAULT_PATH := "res://data/tools.cfg"
const KEYS := ["name", "numeral", "level", "power", "energy_factor"]

static var _default: ToolGradeRules

## {grade id: {key: value}}, as in the file.
var _grades: Dictionary


func _init(grades: Dictionary) -> void:
	_grades = grades


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> ToolGradeRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> ToolGradeRules:
	var rules := ToolGradeRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing, as "[grade] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	if _grades.is_empty():
		found.append("no grades")
	for grade: String in _grades:
		for key: String in KEYS:
			if not _grades[grade].has(key):
				found.append("[%s] no %s" % [grade, key])
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The grade ids from the worst to the best.
func grade_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for grade: String in _grades:
		ids.append(StringName(grade))
	return ids


## The values of a grade, by key (see KEYS).
func grade(grade_id: StringName) -> Dictionary:
	return _grades[str(grade_id)]
