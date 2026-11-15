class_name MusicRules
extends RefCounted
## What the music does, read from data/music.cfg (see there for what every key means): which
## pieces play when nothing else asks, how long one plays before the next comes in, the form each
## piece plays in (a [piece.<name>] section of its own), the quieter mix indoors, the switch between
## a piece's two versions, how long the fades are and how much disk the cache of renders may take.

const DEFAULT_PATH := "res://data/music.cfg"
const BYTES_PER_MEGABYTE := 1000 * 1000
## A piece's own section is this and its name: [piece.sketch_tide].
const PIECE_SECTION := "piece."

const REQUIRED_KEYS := {
	"everyday": ["pieces", "min_seconds", "switch_seconds"],
	"indoors": ["channel_levels", "fade_seconds"],
	"versions": ["fade_seconds"],
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
			var hours: Variant = _values[section].get("hours", [0, 24])
			if (
				not hours is Array
				or hours.size() != 2
				or hours.any(func(hour: Variant) -> bool: return not _is_hour(hour))
			):
				bad.append("[%s] hours must be two whole hours from 0 to 24" % section)
	for key in ["min_seconds", "switch_seconds"]:
		if number("everyday", key) <= 0.0:
			bad.append("[everyday] %s must be above 0" % key)
	var levels: Variant = _values["indoors"]["channel_levels"]
	if (
		not levels is Array
		or levels.size() != TrackerModule.CHANNELS
		or levels.any(func(level: Variant) -> bool: return not _is_share(level))
	):
		bad.append("[indoors] channel_levels must be a share from 0 to 1 for each of 4 channels")
	if indoors_fade_seconds() <= 0.0:
		bad.append("[indoors] fade_seconds must be above 0")
	if versions_fade_seconds() <= 0.0:
		bad.append("[versions] fade_seconds must be above 0")
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


## How long a piece plays at least before another may take over, in seconds.
func min_seconds() -> float:
	return number("everyday", "min_seconds")


## How long a piece plays before the next that fits too takes over, in seconds.
func switch_seconds() -> float:
	return number("everyday", "switch_seconds")


## Whether `piece` fits the hour of the game's clock (0 to 23): its section's `hours`, from and
## to, the second not included (from 16 to 5 runs over midnight); a piece without hours always fits.
func fits(piece: String, hour: int) -> bool:
	var hours: Array = _values.get(PIECE_SECTION + piece, {}).get("hours", [0, 24])
	var from := int(hours[0])
	var to := int(hours[1])
	if from <= to:
		return hour >= from and hour < to
	return hour >= from or hour < to


## The everyday pieces that fit `hour`, in the order of the file; all of them when none does, so
## something always plays.
func fitting_pieces(hour: int) -> Array[String]:
	var fitting := everyday_pieces().filter(func(piece: String) -> bool: return fits(piece, hour))
	var pieces: Array[String] = []
	pieces.assign(everyday_pieces() if fitting.is_empty() else fitting)
	return pieces


## The sections `piece` plays one after the other, round and round (see MusicPiece.parts): its
## section's `form`, or none (its first section alone).
func form(piece: String) -> Array[String]:
	var sections: Array[String] = []
	sections.assign(_values.get(PIECE_SECTION + piece, {}).get("form", []))
	return sections


## The share of its volume each of a module's `channels` plays at in the quieter mix indoors: the
## four of the file for the first four, and again for each four after them (the fuller versions
## keep the roles in fours: the tune, the chords, the bass or drone, the drum or the sea).
func indoors_levels(channels := TrackerModule.CHANNELS) -> PackedFloat32Array:
	var levels := PackedFloat32Array()
	for channel in channels:
		levels.append(_values["indoors"]["channel_levels"][channel % TrackerModule.CHANNELS])
	return levels


## How long the switch between the mixes takes as the player passes a door, in seconds.
func indoors_fade_seconds() -> float:
	return number("indoors", "fade_seconds")


## How long the switch between a piece's two versions takes when the art changes, in seconds.
func versions_fade_seconds() -> float:
	return number("versions", "fade_seconds")


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


static func _is_hour(value: Variant) -> bool:
	return (
		(value is float or value is int) and value == floorf(value) and value >= 0 and value <= 24
	)
