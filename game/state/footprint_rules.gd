class_name FootprintRules
extends RefCounted
## How many footprints a chunk keeps and how fast they fade, read from data/footprints.cfg (see
## there for what each number means). `from_file` reports every key that is missing or out of
## range, and `is_valid` says whether any was.

const DEFAULT_PATH := "res://data/footprints.cfg"
const REQUIRED_KEYS: Array[String] = [
	"per_chunk",
	"snow_lasts_minutes",
	"mud_lasts_minutes",
	"mud_rain_gain",
	"snow_snowfall_gain",
	"snow_thaw_gain",
]

static var _default: FootprintRules

## The keys of the `[footprints]` section, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> FootprintRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> FootprintRules:
	var rules := FootprintRules.new(DataFile.read_sections(path).get("footprints", {}))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[footprints] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	for key in REQUIRED_KEYS:
		if not _values.has(key):
			found.append("[footprints] no %s" % key)
	if not found.is_empty():
		return found
	if per_chunk() < 1:
		found.append("[footprints] per_chunk must be at least 1")
	if snow_lasts_minutes() <= 0.0 or mud_lasts_minutes() <= 0.0:
		found.append("[footprints] a print must last more than 0 minutes")
	if mud_rain_gain() < 0.0 or snow_snowfall_gain() < 0.0 or snow_thaw_gain() < 0.0:
		found.append("[footprints] a gain must not be below 0")
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The prints a chunk keeps.
func per_chunk() -> int:
	return int(_values["per_chunk"])


## The game minutes a print in snow lasts in fair weather.
func snow_lasts_minutes() -> float:
	return float(_values["snow_lasts_minutes"])


## The game minutes a print in mud lasts in fair weather.
func mud_lasts_minutes() -> float:
	return float(_values["mud_lasts_minutes"])


## How much faster prints in mud fade in the strongest rain, on top of the normal pace.
func mud_rain_gain() -> float:
	return float(_values["mud_rain_gain"])


## How much faster prints in snow fade in the heaviest snowfall.
func snow_snowfall_gain() -> float:
	return float(_values["snow_snowfall_gain"])


## How much faster prints in snow fade in the fullest thaw.
func snow_thaw_gain() -> float:
	return float(_values["snow_thaw_gain"])
