class_name MusicRules
extends RefCounted
## What the music does, read from data/music.cfg (see there for what every key means): which
## pieces play when nothing else asks, how often they loop before the next one comes in, how long
## the fades are and how much disk the cache of renders may take.

const DEFAULT_PATH := "res://data/music.cfg"
const BYTES_PER_MEGABYTE := 1000 * 1000

const REQUIRED_KEYS := {
	"everyday": ["pieces", "loops_before_switch"],
	"fades": ["crossfade_seconds", "stop_seconds"],
	"cache": ["max_megabytes"],
}

static var _default: MusicRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> MusicRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> MusicRules:
	var rules := MusicRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what". The values are only checked once every key is
## there.
func problems() -> Array[String]:
	var bad: Array[String] = []
	for section: String in REQUIRED_KEYS:
		for key: String in REQUIRED_KEYS[section]:
			if not _values.get(section, {}).has(key):
				bad.append("[%s] no %s" % [section, key])
	if not bad.is_empty():
		return bad
	if everyday_pieces().is_empty():
		bad.append("[everyday] pieces must name a piece")
	if loops_before_switch() < 1:
		bad.append("[everyday] loops_before_switch must be at least 1")
	for key in ["crossfade_seconds", "stop_seconds"]:
		if number("fades", key) <= 0.0:
			bad.append("[fades] %s must be above 0" % key)
	if cache_bytes() <= 0:
		bad.append("[cache] max_megabytes must be above 0")
	return bad


func is_valid() -> bool:
	return problems().is_empty()


## The pieces that play when nothing else asks, in turn.
func everyday_pieces() -> Array[String]:
	var pieces: Array[String] = []
	pieces.assign(_values["everyday"]["pieces"])
	return pieces


func loops_before_switch() -> int:
	return int(number("everyday", "loops_before_switch"))


func crossfade_seconds() -> float:
	return number("fades", "crossfade_seconds")


func stop_seconds() -> float:
	return number("fades", "stop_seconds")


func cache_bytes() -> int:
	return int(number("cache", "max_megabytes") * BYTES_PER_MEGABYTE)


## A number of the file.
func number(section: String, key: String) -> float:
	return float(_values[section][key])
