class_name LandscapeRules
extends RefCounted
## The numbers of the worked land (field boundaries, ditches, dykes, willows) and of the coast,
## read from data/landscape.cfg (see there for what each one means). `from_file` reports every key
## that is missing or out of range, and `is_valid` says whether any was.

const DEFAULT_PATH := "res://data/landscape.cfg"

const REQUIRED_KEYS := {
	"fields": ["row_height", "row_jitter", "field_width", "field_jitter", "boundary_chance"],
	"kinds": ["knick", "stone_wall", "wattle_fence"],
	"marsh": ["reach"],
	"dykes": ["stretch_above"],
	"ditches": ["willow_chance", "reeds_chance"],
	"coast": ["line_x", "wander", "salt_marsh_width", "salt_marsh_wander", "flats_width"],
	"tideways": ["spacing", "meander", "widening", "widest"],
}
## A field must leave room for a gap that is not at either end of a boundary, with a tile
## beside it on both sides that is not on another boundary.
const MIN_FIELD_SIZE := 6

static var _default: LandscapeRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> LandscapeRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> LandscapeRules:
	var rules := LandscapeRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	for section: String in REQUIRED_KEYS:
		for key: String in REQUIRED_KEYS[section]:
			if not _values.get(section, {}).has(key):
				found.append("[%s] no %s" % [section, key])
	if not found.is_empty():
		return found
	if value("fields", "row_height") - value("fields", "row_jitter") < MIN_FIELD_SIZE:
		found.append("[fields] row_height less row_jitter must be at least %d" % MIN_FIELD_SIZE)
	if value("fields", "field_width") - value("fields", "field_jitter") < MIN_FIELD_SIZE:
		found.append("[fields] field_width less field_jitter must be at least %d" % MIN_FIELD_SIZE)
	var tideway_band := 2.0 * value("tideways", "meander") + value("tideways", "widest")
	if tideway_band >= value("tideways", "spacing"):
		found.append("[tideways] twice the meander and the widest must be less than the spacing")
	if kind_shares().values().all(func(share: float) -> bool: return share <= 0.0):
		found.append("[kinds] no kind has a share")
	return found


func is_valid() -> bool:
	return problems().is_empty()


## A number of the file, e.g. `value("fields", "row_height")`.
func value(section: String, key: String) -> float:
	return float(_values[section][key])


## The share of each kind of field boundary on the Geest, by object type, in the order of the
## file.
func kind_shares() -> Dictionary[StringName, float]:
	var shares: Dictionary[StringName, float] = {}
	for key: String in REQUIRED_KEYS["kinds"]:
		shares[StringName(key)] = value("kinds", key)
	return shares
