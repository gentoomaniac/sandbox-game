class_name BuildingRules
extends RefCounted
## The buildings and their styles, read from data/buildings.cfg (see there for what each key
## means). `from_file` reports every required key that is missing or wrong, and `is_valid` says
## whether any was. BuildingTypes builds its table from `default_rules`.

const DEFAULT_PATH := "res://data/buildings.cfg"
## Between the building's id and the style's in the section of a style: [kate.brick].
const STYLE_SEPARATOR := "."
## What a style can't change: these make it the same house as its building.
const SAME_HOUSE_KEYS: Array[String] = ["footprint", "door_offset", "interior_map"]

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
## {building id: {style id: {key: value}}}: each building's styles in the order of the file, its
## own first as &"". A style's values are its building's with the style's own over them.
var _styles: Dictionary
var _problems: Array[String] = []


## `sections` as the file has them, {section: {key: value}}.
func _init(sections: Dictionary) -> void:
	for section: String in sections:
		if STYLE_SEPARATOR not in section:
			_buildings[section] = sections[section]
			_styles[section] = {&"": sections[section]}
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
	for section: String in sections:
		if STYLE_SEPARATOR in section:
			_add_style(section, sections[section])


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> BuildingRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> BuildingRules:
	var rules := BuildingRules.new(DataFile.read_sections(path))
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


## A building's styles, in the order of the file: its own first, as &"".
func style_ids(building_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_styles[str(building_id)].keys())
	return ids


## One style's values: its building's, with those the style sets over them.
func style(building_id: StringName, style_id: StringName) -> Dictionary:
	return _styles[str(building_id)][style_id]


func _add_style(section: String, values: Dictionary) -> void:
	var building_id := section.get_slice(STYLE_SEPARATOR, 0)
	var style_id := StringName(section.get_slice(STYLE_SEPARATOR, 1))
	if section.get_slice_count(STYLE_SEPARATOR) != 2 or style_id.is_empty():
		_problems.append("[%s] style id must be one word" % section)
		return
	if not _buildings.has(building_id):
		_problems.append("[%s] is a style of no building" % section)
		return
	if not values.has("name"):
		_problems.append("[%s] no name" % section)
	for key in SAME_HOUSE_KEYS:
		if values.has(key):
			_problems.append("[%s] %s is the building's" % [section, key])
	_styles[building_id][style_id] = _buildings[building_id].merged(values, true)
