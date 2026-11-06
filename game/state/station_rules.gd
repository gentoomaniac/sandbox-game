class_name StationRules
extends RefCounted
## The crafting stations, read from data/stations.cfg (see there for what each key means).
## `from_file` reports every key that is missing or wrong, and `is_valid` says whether any was.

const DEFAULT_PATH := "res://data/stations.cfg"

const REQUIRED_KEYS: Array[String] = ["name", "objects"]

static var _default: StationRules

## {station id: {key: value}}, in the order of the file.
var _stations: Dictionary
## Object type -> the station it is.
var _station_of_object: Dictionary[StringName, StringName] = {}
var _problems: Array[String] = []


func _init(stations: Dictionary) -> void:
	_stations = stations
	if _stations.is_empty():
		_problems.append("no stations")
	for station: String in _stations:
		var values: Dictionary = _stations[station]
		for key in REQUIRED_KEYS:
			if not values.has(key):
				_problems.append("[%s] no %s" % [station, key])
		if values.has("objects"):
			_read_objects(station, values["objects"])


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> StationRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> StationRules:
	var rules := StationRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	return _problems


func is_valid() -> bool:
	return _problems.is_empty()


func has_station(station: StringName) -> bool:
	return _stations.has(str(station))


## The title of the station's menu.
func station_name(station: StringName) -> String:
	return _stations[str(station)]["name"]


## The station an object of this type is, or &"" if it is none.
func station_of(object_type: StringName) -> StringName:
	return _station_of_object.get(object_type, &"")


func _read_objects(station: String, objects: Variant) -> void:
	if not objects is Array or objects.is_empty():
		_problems.append("[%s] objects must be a list of at least one object type" % station)
		return
	for object: Variant in objects:
		var object_type := StringName(str(object))
		if not WorldObjectTypes.TYPES.has(object_type):
			_problems.append("[%s] not an object type: %s" % [station, object])
		elif _station_of_object.has(object_type):
			_problems.append("[%s] %s is already a station" % [station, object])
		else:
			_station_of_object[object_type] = StringName(station)
