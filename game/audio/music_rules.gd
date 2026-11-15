class_name MusicRules
extends RefCounted
## What the music does, read from data/music.cfg (see there for what every key means): which
## pieces play when nothing else asks, how long one plays before the next comes in, the form each
## piece plays in (a [piece.<name>] section of its own), the quieter mix indoors, how long the
## fades are and how much disk the cache of renders may take.

const DEFAULT_PATH := "res://data/music.cfg"
const BYTES_PER_MEGABYTE := 1000 * 1000
## A piece's own section is this and its name: [piece.sketch_tide].
const PIECE_SECTION := "piece."

const REQUIRED_KEYS := {
	"everyday": ["pieces", "switch_seconds"],
	"indoors": ["channel_levels", "fade_seconds"],
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
	for section: String in _values:
		if section.begins_with(PIECE_SECTION):
			var form: Variant = _values[section].get("form", [])
			if (
				not form is Array
				or form.any(func(part: Variant) -> bool: return part is not String)
			):
				bad.append("[%s] form must be a list of section names" % section)
	if switch_seconds() <= 0.0:
		bad.append("[everyday] switch_seconds must be above 0")
	var levels: Variant = _values["indoors"]["channel_levels"]
	if (
		not levels is Array
		or levels.size() != TrackerModule.CHANNELS
		or levels.any(func(level: Variant) -> bool: return not _is_share(level))
	):
		bad.append("[indoors] channel_levels must be a share from 0 to 1 for each of 4 channels")
	if indoors_fade_seconds() <= 0.0:
		bad.append("[indoors] fade_seconds must be above 0")
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


## How long a piece plays before the next comes in, in seconds.
func switch_seconds() -> float:
	return number("everyday", "switch_seconds")


## The sections `piece` plays one after the other, round and round (see MusicPiece.parts): its
## section's `form`, or none (its first section alone).
func form(piece: String) -> Array[String]:
	var sections: Array[String] = []
	sections.assign(_values.get(PIECE_SECTION + piece, {}).get("form", []))
	return sections


## The share of its volume each channel plays at in the quieter mix indoors.
func indoors_levels() -> PackedFloat32Array:
	return PackedFloat32Array(_values["indoors"]["channel_levels"])


## How long the switch between the mixes takes as the player passes a door, in seconds.
func indoors_fade_seconds() -> float:
	return number("indoors", "fade_seconds")


func crossfade_seconds() -> float:
	return number("fades", "crossfade_seconds")


func stop_seconds() -> float:
	return number("fades", "stop_seconds")


func cache_bytes() -> int:
	return int(number("cache", "max_megabytes") * BYTES_PER_MEGABYTE)


## A number of the file.
func number(section: String, key: String) -> float:
	return float(_values[section][key])


static func _is_share(value: Variant) -> bool:
	return (value is float or value is int) and value >= 0.0 and value <= 1.0
