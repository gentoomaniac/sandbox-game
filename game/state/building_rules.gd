class_name BuildingRules
extends RefCounted
## The buildings, read from data/buildings.cfg (see there for what each key means).
## `from_file` reports every required key that is missing or wrong, and `is_valid` says
## whether any was. BuildingTypes builds its table from `default_rules`.

const DEFAULT_PATH := "res://data/buildings.cfg"

const REQUIRED_KEYS: Array[String] = [
	"name",
	"footprint",
	"door_offset",
	"sprite",
	"sprite_lit",
	"interior_map",
	"window_lights",
	"window_light",
	"cost_logs",
	"cost_stone",
	"cost_clay",
	"cost_reeds",
	"beds",
	"storage_slots",
	"warmth",
	"comfort",
]

static var _default: BuildingRules

## {building id: {key: value}}, in the order of the file.
var _buildings: Dictionary
var _problems: Array[String] = []


func _init(buildings: Dictionary) -> void:
	_buildings = buildings
	if _buildings.is_empty():
		_problems.append("no buildings")
	for building_id: String in _buildings:
		var values: Dictionary = _buildings[building_id]
		for key in REQUIRED_KEYS:
			if not values.has(key):
				_problems.append("[%s] no %s" % [building_id, key])
		if values.get("footprint") is Vector2i and values.get("door_offset") is Vector2i:
			var footprint: Vector2i = values["footprint"]
			var door: Vector2i = values["door_offset"]
			if door.y != footprint.y - 1 or door.x < 0 or door.x >= footprint.x:
				_problems.append("[%s] door_offset must be a tile of the bottom row" % building_id)


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> BuildingRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> BuildingRules:
	var file := ConfigFile.new()
	var error := file.load(path)
	if error != OK:
		push_error("Can't read %s: %s" % [path, error_string(error)])
	var buildings := {}
	for section in file.get_sections():
		buildings[section] = {}
		for key in file.get_section_keys(section):
			buildings[section][key] = file.get_value(section, key)
	var rules := BuildingRules.new(buildings)
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	return _problems


func is_valid() -> bool:
	return _problems.is_empty()


## The building ids, in the order of the file.
func building_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for building_id: String in _buildings:
		ids.append(StringName(building_id))
	return ids


## One building's values, as in the file.
func building(building_id: StringName) -> Dictionary:
	return _buildings[str(building_id)]
