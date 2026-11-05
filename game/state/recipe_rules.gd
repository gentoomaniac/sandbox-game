class_name RecipeRules
extends RefCounted
## The crafting recipes, read from data/recipes.cfg (see there for what each key means).
## `from_file` reports every required key that is missing or wrong, and `is_valid` says whether
## any was. The crafting menu and Crafting use `default_rules`.

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


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> RecipeRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> RecipeRules:
	var file := ConfigFile.new()
	var error := file.load(path)
	if error != OK:
		push_error("Can't read %s: %s" % [path, error_string(error)])
	var recipes := {}
	for section in file.get_sections():
		recipes[section] = {}
		for key in file.get_section_keys(section):
			recipes[section][key] = file.get_value(section, key)
	var rules := RecipeRules.new(recipes)
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
