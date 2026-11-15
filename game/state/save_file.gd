class_name SaveFile
extends RefCounted
## The saves on disk: a JSON file per save, `{"version": VERSION, "game": <GameState.to_dict>}`.
## Every save is a new file, and the newest few are kept (see SaveList).
## Saves from OLDEST_VERSION to VERSION (ten upgrade steps) still load, upgraded step by step
## (see `_upgrade_from_version_39` and so on). Older ones are refused.
##
## How to add a save field (or change one):
## 1. Write it in `to_dict` and read it in `from_dict` with `data["name"]`. Never `data.get(...)`
##    with a default: a save without the field is a bug to see, not to hide. A big map is copied in
##    `snapshot` instead and made data in `dict_of` (see World), which the worker thread does.
## 2. Raise VERSION by one.
## 3. Add `_upgrade_from_version_<old VERSION>` here, which gives the field to a save of the old
##    version (its default, or computed from what the save has), and call it from `read`.
## 4. Add a test in tests/test_save_upgrade*.gd: an old save without the field loads right.
## 5. Drop the oldest step, the constants and helpers only it uses, and its tests, so that ten
##    steps remain (OLDEST_VERSION moves up with VERSION). That is a commit of its own, titled
##    `Save: drop the upgrade from version <N> (oldest read: <N+1>)`: to rescue a save older
##    than that, find the commit with `git log --grep '^Save: drop'` and check out its parent,
##    which still upgrades it; load and save the game there, then move on to the latest.
## An upgrade step works on the parsed JSON, before any `from_dict` runs. After the upgrades the
## SaveValidator checks the whole game data: `from_dict` is strict (it asserts) and trusts that.
## So a field added in step 1 is checked there too: add its check to the validator.

const VERSION := 48
## The oldest version we still upgrade. Nine steps back, for the next version (#9) makes its step
## the tenth.
const OLDEST_VERSION := VERSION - 9
## The world's save path: its saves are named after it (see SaveList).
const DEFAULT_PATH := "user://saves/world.json"
## What ends the name of a backup (see `free_backup_path`): a save we can't use is
## moved there, and one loaded without its missing content is copied there.
const BACKUP_SUFFIX := ".bak"
## The day and minute stamps the upgrade from version 43 moves to the 35-day seasons. The names are
## written out, so that a later field of the same name is left alone.
const DAY_STAMP_KEYS := [
	"day", "placed_day", "last_petted_day", "last_petted_asleep_day", "opinion_day"
]
const MINUTE_STAMP_KEYS := ["follow_until_minute", "start_minute", "done_minute", "learned_at"]


## Writes the game as a new save of the world at `base`. Returns whether it worked.
static func write(
	state: GameState, base: String = DEFAULT_PATH, kind := SaveHeader.Kind.QUICK_SAVE
) -> bool:
	return store(encode(state), SaveHeader.of(state, kind), base) == ""


## The game of this moment, copied so that it shares nothing with the running game: another thread
## can make text of it (`text_of`) while the game goes on. Taking it must happen on the main
## thread, and it takes little of it: the big parts of the game are copied as they are, not made
## into save data yet (see GameState `snapshot`).
static func snapshot(state: GameState) -> Dictionary:
	return {"version": VERSION, "game": state.snapshot()}


## The text of a save file for a snapshot. Safe to call from a thread.
static func text_of(snapshot_data: Dictionary) -> String:
	var data := snapshot_data.duplicate()
	data["game"] = GameState.dict_of(snapshot_data["game"])
	return JSON.stringify(data, "\t")


## The game as the text of a save file, all on this thread.
static func encode(state: GameState) -> String:
	return text_of(snapshot(state))


## Writes the text of a save as a new save of the world at `base`, with its `header`, and deletes
## the saves beyond the newest few. Returns what went wrong, or "" when it is written. Safe to
## call from a thread. The header goes first and the save last, so a save is never listed without
## its header; whatever fails, the saves that were there stay as they were.
static func store(text: String, header: SaveHeader, base: String) -> String:
	var save_path := SaveList.next_path(base)
	var error := write_text(header.to_text(), SaveList.header_path_of(save_path))
	if error != "":
		return error
	error = write_text(text, save_path)
	if error != "":
		DirAccess.remove_absolute(SaveList.header_path_of(save_path))
		return error
	SaveList.prune(base)
	return ""


## Writes the text of a save to `path`. Returns what went wrong, or "" when it is written (also
## reported as an error). Safe to call from a thread. It is written beside the save and renamed
## over it, and every step is checked: whatever fails, the save that was there stays as it was.
static func write_text(text: String, path: String) -> String:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return _write_failed("Can't create the save folder: %s" % error_string(error))
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var reason := error_string(FileAccess.get_open_error())
		return _write_failed("Can't write %s: %s" % [temp_path, reason])
	var is_stored := file.store_string(text)
	file.flush()
	error = file.get_error()
	file.close()
	if not is_stored or error != OK:
		DirAccess.remove_absolute(temp_path)
		return _write_failed("Can't write %s: %s" % [temp_path, error_string(error)])
	error = DirAccess.rename_absolute(temp_path, path)
	if error != OK:
		DirAccess.remove_absolute(temp_path)
		return _write_failed("Can't replace %s: %s" % [path, error_string(error)])
	return ""


static func _write_failed(problem: String) -> String:
	push_error(problem)
	return problem


## Reads the save at `path` and checks it (see SaveValidator). The file is not changed: what
## becomes of a refused one is the caller's to decide (`move_aside`). A save that is whole but
## holds things the game no longer has is told apart from a refused one (see LoadResult).
static func load_game(path: String) -> LoadResult:
	if not FileAccess.file_exists(path):
		return LoadResult.no_save()
	# Not parse_string: it prints an engine error of its own for broken text.
	var json := JSON.new()
	var parsed: Variant = (
		json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	)
	if not parsed is Dictionary:
		return LoadResult.refused(["not a save file"] as Array[String])
	# JSON parsing gives numbers as floats.
	var version: Variant = parsed.get("version")
	var is_supported: bool = (
		version is float
		and version == int(version)
		and version >= OLDEST_VERSION
		and version <= VERSION
	)
	if not is_supported:
		var reason := "save version %s, this game reads versions %d to %d"
		return LoadResult.refused([reason % [version, OLDEST_VERSION, VERSION]] as Array[String])
	if not parsed.get("game") is Dictionary:
		return LoadResult.refused(["no game in the save"] as Array[String])
	var game: Dictionary = parsed["game"]
	_upgrade(game, int(version))
	var validator := SaveValidator.check(game)
	if not validator.problems.is_empty():
		return LoadResult.refused(validator.problems)
	if not validator.missing.is_empty():
		return LoadResult.asking(game, validator, path)
	return LoadResult.ready(GameState.from_dict(game))


## The newest save of the world at `base` that gives a game, or null if there is none. A save
## that gives no game, or holds content the game no longer has (`load_game` tells these apart, for
## a caller that asks the player), is reported and moved aside (`move_aside`), and the one before
## it is tried.
static func read(base: String = DEFAULT_PATH) -> GameState:
	for path in SaveList.paths_newest_first(base):
		var result := load_game(path)
		match result.outcome:
			LoadResult.Outcome.READY:
				return result.state
			LoadResult.Outcome.REFUSED:
				push_error("Can't load %s: %s" % [path, "; ".join(result.problems)])
			LoadResult.Outcome.ASK:
				push_error("Can't load %s: it holds %s" % [path, "; ".join(result.missing)])
		move_aside(path)
	return null


## Where a backup of the save at `path` goes, named with the date and time so that backups sort
## by age: `user://saves/world.2026-11-09_21-45-03.json.bak`. A second one in the same second gets
## a number (`..._21-45-03-2.json.bak`), so that a backup never replaces another.
static func free_backup_path(path: String) -> String:
	var stamp := Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	var stem := "%s.%s" % [path.get_basename(), stamp]
	var backup := "%s.%s%s" % [stem, path.get_extension(), BACKUP_SUFFIX]
	var number := 2
	while FileAccess.file_exists(backup):
		backup = "%s-%d.%s%s" % [stem, number, path.get_extension(), BACKUP_SUFFIX]
		number += 1
	return backup


## The backups of the save at `path` that exist, oldest first.
static func backups_of(path: String) -> Array[String]:
	var prefix := path.get_file().get_basename() + "."
	var suffix := "." + path.get_extension() + BACKUP_SUFFIX
	var found: Array[String] = []
	for file_name in DirAccess.get_files_at(path.get_base_dir()):
		if file_name.begins_with(prefix) and file_name.ends_with(suffix):
			found.append(path.get_base_dir().path_join(file_name))
	found.sort()
	return found


## Renames a save we can't use out of the way, so that it is never overwritten silently (its
## header is deleted: the backup is not in the list). Returns where it went, or "" if it could not
## be moved.
static func move_aside(path: String) -> String:
	var backup := free_backup_path(path)
	var error := DirAccess.rename_absolute(path, backup)
	if error != OK:
		push_error("Can't move %s to %s: %s" % [path, backup, error_string(error)])
		return ""
	DirAccess.remove_absolute(SaveList.header_path_of(path))
	return backup


## Copies the save at `path` to `backup` (see `free_backup_path`), for a save that is about to be
## loaded in a way that its next write changes. Returns what went wrong, or "" if it worked.
static func copy_aside(path: String, backup: String) -> String:
	var error := DirAccess.copy_absolute(path, backup)
	if error == OK:
		return ""
	var problem := "Can't copy %s to %s: %s" % [path, backup, error_string(error)]
	push_error(problem)
	return problem


## Brings the data of a save of `version` up to the current one.
static func _upgrade(game: Dictionary, version: int) -> void:
	if version <= 39:
		_upgrade_from_version_39(game)
	if version <= 40:
		_upgrade_from_version_40(game)
	if version <= 41:
		_upgrade_from_version_41(game)
	if version <= 42:
		_upgrade_from_version_42(game)
	if version <= 43:
		_upgrade_from_version_43(game)
	if version <= 44:
		_upgrade_from_version_44(game)
	if version <= 45:
		_upgrade_from_version_45(game)
	if version <= 46:
		_upgrade_from_version_46(game)
	if version <= 47:
		_upgrade_from_version_47(game)


## Version 39 had lanterns that burnt no candle (task 231): every lantern, in a stack of the player
## or a chest or in a pile on the ground, holds a fresh candle.
static func _upgrade_from_version_39(game: Dictionary) -> void:
	_give_lanterns_a_candle(game)


## Version 40 had campfires that burnt for ever (task 56): every fireplace has a slot for wood, and
## burns on with 4 logs, one of them burning.
static func _upgrade_from_version_40(game: Dictionary) -> void:
	# Written out, not read from data/lighting.cfg, so a later change leaves old saves alone.
	var wood_slot := {"item": "logs", "count": 3}
	var log_minutes := 3 * GameClock.MINUTES_PER_HOUR
	for edit: Dictionary in game["world"]["object_edits"]:
		var object: Variant = edit["object"]
		if object != null and object["type"] == "fireplace":
			object["storage"] = [wood_slot.duplicate()]
			object["state"]["lit"] = true
			object["state"]["log_left"] = log_minutes


## Version 41 had horses that never tired (#66): every animal has stamina, a horse a full one.
static func _upgrade_from_version_41(game: Dictionary) -> void:
	for animal: Dictionary in game["livestock"]:
		animal["stamina"] = 1.0


## Version 42 counted the wear of desire paths in steps (#61): a tile with 8 steps was trodden and
## one with 24 a path. They are counted in days of wear now, and a tile keeps the look it had: 3
## days make a tile trodden and 8 a path; the steps of less worn tiles are forgotten, and no
## tile has taken steps today.
static func _upgrade_from_version_42(game: Dictionary) -> void:
	# Written out, not read from data/paths.cfg, so a later change leaves old saves alone.
	var trodden_from_steps := 8.0
	var path_from_steps := 24.0
	var trodden_days := 3
	var path_days := 8
	var days: Array = []
	for entry: Array in game["world"]["wear"]:
		if entry[2] >= path_from_steps:
			days.append([entry[0], entry[1], path_days])
		elif entry[2] >= trodden_from_steps:
			days.append([entry[0], entry[1], trodden_days])
	game["world"]["wear"] = days
	game["world"]["wear_today"] = []


## Version 43 had seasons of 30 days and years of 120 (#85); they have 35 and 140 now. A saved day
## keeps its year, season and day of the season, so the save stays in the season it was in: day
## 130, the 10th day of spring in year 2, is day 150. Every other day and minute the save holds
## (the deeds, chats and memories, what a kiln, a rooster or a scarecrow counts from) moves the
## same way, so each is as long ago as it was, give or take the five new days of a season.
static func _upgrade_from_version_43(game: Dictionary) -> void:
	_move_to_longer_seasons(game)


static func _move_to_longer_seasons(data: Variant) -> void:
	if data is Array:
		for entry: Variant in data:
			_move_to_longer_seasons(entry)
	elif data is Dictionary:
		for key: String in data:
			var value: Variant = data[key]
			var is_number: bool = value is int or value is float
			if key in DAY_STAMP_KEYS and is_number:
				data[key] = _day_in_longer_seasons(int(value))
			elif key in MINUTE_STAMP_KEYS and is_number:
				data[key] = _minute_in_longer_seasons(int(value))
			elif key == "origin" and value is String and "|" in value:
				# A story's deed, as "day|kind|place" (see DeedLog).
				var parts: PackedStringArray = value.split("|", true, 1)
				data[key] = "%d|%s" % [_day_in_longer_seasons(int(parts[0])), parts[1]]
			else:
				_move_to_longer_seasons(value)


## Day 0 is "never" and stays so.
static func _day_in_longer_seasons(day: int) -> int:
	if day < 1:
		return day
	var days_since_start := day - 1
	var year := days_since_start / 120
	var day_of_year := days_since_start % 120
	return year * 140 + day_of_year / 30 * 35 + day_of_year % 30 + 1


static func _minute_in_longer_seasons(minute: int) -> int:
	var day := _day_in_longer_seasons(minute / GameClock.MINUTES_PER_DAY + 1)
	return (day - 1) * GameClock.MINUTES_PER_DAY + minute % GameClock.MINUTES_PER_DAY


## Version 44 had the old generator's land (a grid of fields and ditches, woods of single trees, a
## straight river; #60). A save holds only the seed and the edits, so nothing in the data changes:
## the land it has not edited is the new generator's, and its seams with the edits may look odd.
static func _upgrade_from_version_44(_game: Dictionary) -> void:
	pass


## Version 45 had no village (#9): the world has none, and keeps the land it has.
static func _upgrade_from_version_45(game: Dictionary) -> void:
	game["world"]["village"] = null


## Version 46 had no plans of the villagers' days from the language model (#7): every villager has
## the default day until the planner asks.
static func _upgrade_from_version_46(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		npc["day_plans"] = []


## Version 47 had no villagers inside buildings (#8): they were all in the open, as they stand.
static func _upgrade_from_version_47(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		npc["inside"] = null


static func _give_lanterns_a_candle(data: Variant) -> void:
	if data is Array:
		for entry: Variant in data:
			_give_lanterns_a_candle(entry)
	elif data is Dictionary:
		if data.get("item") == "lantern" and data.get("count") == 1:
			data["state"] = {"candle": {}}
		for entry: Variant in data.values():
			_give_lanterns_a_candle(entry)
