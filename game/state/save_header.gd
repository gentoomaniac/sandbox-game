class_name SaveHeader
extends RefCounted
## What the load list says of a save without loading the world: when in the game and in real life
## it was made, and what made it. It lives in a small file beside the save (see
## `SaveList.header_path_of`), so that listing the saves does not parse a world for each.

## What made a save. EARLIER is a save from before there were headers.
enum Kind { AUTOSAVE, QUICK_SAVE, SLEEP, QUIT, EARLIER }

## The words for the player.
const KIND_NAMES := {
	Kind.AUTOSAVE: "autosave",
	Kind.QUICK_SAVE: "quick save",
	Kind.SLEEP: "sleep",
	Kind.QUIT: "save and quit",
	Kind.EARLIER: "earlier save",
}
const SECONDS_PER_MINUTE := 60

var kind: Kind
## The version of the save, so that the list can tell one this game can't read.
var version: int
var game_day: int
var game_minute_of_day: int
## When the save was made, in seconds since 1970 (UTC).
var unix_time: int


## The header of the game `state` as it is now, saved for `save_kind`.
static func of(state: GameState, save_kind: Kind) -> SaveHeader:
	return _made(save_kind, SaveFile.VERSION, state.clock, int(Time.get_unix_time_from_system()))


## The header of a save from before there were headers, read from the save's data and the time its
## file was last changed. Null when the data holds no clock.
static func of_earlier_save(
	game_data: Variant, version_in_file: Variant, file_time: int
) -> SaveHeader:
	if not (game_data is Dictionary and game_data.get("clock") is Dictionary):
		return null
	var clock := GameClock.from_dict(game_data["clock"])
	return _made(Kind.EARLIER, int(version_in_file), clock, file_time)


## The header in the text of its file, or null if the text is not one.
static func from_text(text: String) -> SaveHeader:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	var data: Dictionary = json.data
	for key: String in ["kind", "version", "game_day", "game_minute_of_day", "unix_time"]:
		if not data.get(key) is float:
			return null
	if not int(data["kind"]) in Kind.values():
		return null
	var header := SaveHeader.new()
	header.kind = int(data["kind"]) as Kind
	header.version = int(data["version"])
	header.game_day = int(data["game_day"])
	header.game_minute_of_day = int(data["game_minute_of_day"])
	header.unix_time = int(data["unix_time"])
	return header


static func _made(save_kind: Kind, save_version: int, clock: GameClock, time: int) -> SaveHeader:
	var header := SaveHeader.new()
	header.kind = save_kind
	header.version = save_version
	header.game_day = clock.day
	header.game_minute_of_day = clock.minute_of_day
	header.unix_time = time
	return header


func to_text() -> String:
	var data := {
		"kind": kind,
		"version": version,
		"game_day": game_day,
		"game_minute_of_day": game_minute_of_day,
		"unix_time": unix_time,
	}
	return JSON.stringify(data)


## "10th day of Spring Year 2, 06:00"
func game_text() -> String:
	var clock := GameClock.new()
	clock.day = game_day
	clock.minute_of_day = game_minute_of_day
	return "%s, %s" % [clock.date_text(), clock.time_text()]


## "autosave, 2026-11-15 10:27", in the local time.
func how_text() -> String:
	var local_time: int = unix_time + Time.get_time_zone_from_system().bias * SECONDS_PER_MINUTE
	var date_and_time := Time.get_datetime_string_from_unix_time(local_time, true)
	return "%s, %s" % [KIND_NAMES[kind], date_and_time.left(16)]


## Whether this game reads the save the header belongs to.
func is_version_supported() -> bool:
	return version >= SaveFile.OLDEST_VERSION and version <= SaveFile.VERSION
