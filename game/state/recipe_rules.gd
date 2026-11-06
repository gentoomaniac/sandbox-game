class_name RecipeRules
extends RefCounted
## The crafting recipes, read from data/recipes.cfg (see there for what each key means).
## `from_file` reports every key that is missing or wrong, and `is_valid` says whether any was.
## The crafting menu and Crafting use `default_rules`. Stations and skills are checked against
## the default StationRules and SkillRules.

const DEFAULT_PATH := "res://data/recipes.cfg"

const REQUIRED_KEYS: Array[String] = ["result", "count", "materials"]

static var _default: RecipeRules

## {recipe id: {key: value}}, in the order of the file.
var _recipes: Dictionary
var _problems: Array[String] = []


func _init(recipes: Dictionary) -> void:
	_recipes = recipes
	if _recipes.is_empty():
		_problems.append("no recipes")
	for recipe_id: String in _recipes:
		var values: Dictionary = _recipes[recipe_id]
		for key in REQUIRED_KEYS:
			if not values.has(key):
				_problems.append("[%s] no %s" % [recipe_id, key])
		_check_result(recipe_id, values)
		_check_materials(recipe_id, values)
		_check_station_and_skill(recipe_id, values)


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> RecipeRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> RecipeRules:
	var rules := RecipeRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	return _problems


func is_valid() -> bool:
	return _problems.is_empty()


## The recipe ids, in the order of the file.
func recipe_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for recipe_id: String in _recipes:
		ids.append(StringName(recipe_id))
	return ids


## The recipes made at a station (or by hand, for &""), in the order of the file.
func recipes_at(station: StringName) -> Array[StringName]:
	return recipe_ids().filter(
		func(recipe_id: StringName) -> bool: return station_of(recipe_id) == station
	)


## Where a recipe is made: a station id, or &"" by hand.
func station_of(recipe_id: StringName) -> StringName:
	return StringName(_recipes[str(recipe_id)].get("station", ""))


## The skill a recipe practises, or &"" for none.
func skill(recipe_id: StringName) -> StringName:
	return StringName(_recipes[str(recipe_id)].get("skill", ""))


## The points of its skill a recipe needs.
func level(recipe_id: StringName) -> float:
	return float(_recipes[str(recipe_id)].get("level", 0.0))


## The item a recipe makes.
func result(recipe_id: StringName) -> StringName:
	return StringName(_recipes[str(recipe_id)]["result"])


## How many of the result one crafting gives.
func count(recipe_id: StringName) -> int:
	return _recipes[str(recipe_id)]["count"]


## What one crafting takes, item id to count.
func materials(recipe_id: StringName) -> Dictionary:
	var materials_by_item := {}
	var values: Dictionary = _recipes[str(recipe_id)]["materials"]
	for item: String in values:
		materials_by_item[StringName(item)] = values[item]
	return materials_by_item


func _check_result(recipe_id: String, values: Dictionary) -> void:
	if values.has("result") and not ItemTypes.TYPES.has(StringName(str(values["result"]))):
		_problems.append("[%s] result is not an item: %s" % [recipe_id, values["result"]])
	if values.has("count") and not (values["count"] is int and values["count"] >= 1):
		_problems.append("[%s] count must be a whole number, at least 1" % recipe_id)


func _check_materials(recipe_id: String, values: Dictionary) -> void:
	if not values.has("materials"):
		return
	var materials_value: Variant = values["materials"]
	if not materials_value is Dictionary or materials_value.is_empty():
		_problems.append("[%s] materials must be a dictionary with at least one item" % recipe_id)
		return
	for item: Variant in materials_value:
		if not ItemTypes.TYPES.has(StringName(str(item))):
			_problems.append("[%s] material is not an item: %s" % [recipe_id, item])
		elif not (materials_value[item] is int and materials_value[item] >= 1):
			_problems.append(
				"[%s] material %s needs a whole number, at least 1" % [recipe_id, item]
			)


func _check_station_and_skill(recipe_id: String, values: Dictionary) -> void:
	var station := StringName(str(values.get("station", "")))
	if values.has("station") and not StationRules.default_rules().has_station(station):
		_problems.append("[%s] station is not a station: %s" % [recipe_id, values["station"]])
	var skill_rules := SkillRules.default_rules()
	if values.has("skill") and not skill_rules.has_skill(StringName(str(values["skill"]))):
		_problems.append("[%s] skill is not a skill: %s" % [recipe_id, values["skill"]])
	if not values.has("level"):
		return
	var level_value: Variant = values["level"]
	if not values.has("skill"):
		_problems.append("[%s] a level needs a skill" % recipe_id)
	elif not (level_value is int or level_value is float):
		_problems.append("[%s] level must be a number" % recipe_id)
	elif level_value < 0 or level_value > skill_rules.skill_cap():
		_problems.append("[%s] level must be from 0 to %s" % [recipe_id, skill_rules.skill_cap()])
