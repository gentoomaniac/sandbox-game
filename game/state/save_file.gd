class_name SaveFile
extends RefCounted
## The save on disk: one JSON file per world, `{"version": VERSION, "game": <GameState.to_dict>}`.
## Saves from OLDEST_VERSION to VERSION (ten upgrade steps) still load, upgraded step by step
## (see `_upgrade_from_version_33` and so on). Older ones are refused.
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

const VERSION := 43
## The oldest version we still upgrade.
const OLDEST_VERSION := VERSION - 10
const DEFAULT_PATH := "user://saves/world.json"
## What ends the name of a backup (see `free_backup_path`): a save we can't use is
## moved there, and one loaded without its missing content is copied there.
const BACKUP_SUFFIX := ".bak"


## Writes the game to `path`. Returns whether it worked.
static func write(state: GameState, path: String = DEFAULT_PATH) -> bool:
	return write_text(encode(state), path) == ""


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
static func load_game(path: String = DEFAULT_PATH) -> LoadResult:
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


## The saved game, or null if there is no save, it is refused or it holds content the game no
## longer has (`load_game` tells these apart, for a caller that asks the player). A save that
## gives no game is reported and moved aside (`move_aside`): the caller starts a new game.
static func read(path: String = DEFAULT_PATH) -> GameState:
	var result := load_game(path)
	match result.outcome:
		LoadResult.Outcome.REFUSED:
			push_error("Can't load %s: %s" % [path, "; ".join(result.problems)])
			move_aside(path)
		LoadResult.Outcome.ASK:
			push_error("Can't load %s: it holds %s" % [path, "; ".join(result.missing)])
			move_aside(path)
	return result.state


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


## Renames a save we can't use out of the way, so that it is never overwritten silently. Returns
## where it went, or "" if it could not be moved.
static func move_aside(path: String) -> String:
	var backup := free_backup_path(path)
	var error := DirAccess.rename_absolute(path, backup)
	if error != OK:
		push_error("Can't move %s to %s: %s" % [path, backup, error_string(error)])
		return ""
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
	if version <= 33:
		_upgrade_from_version_33(game)
	if version <= 34:
		_upgrade_from_version_34(game)
	if version <= 35:
		_upgrade_from_version_35(game)
	if version <= 36:
		_upgrade_from_version_36(game)
	if version <= 37:
		_upgrade_from_version_37(game)
	if version <= 38:
		_upgrade_from_version_38(game)
	if version <= 39:
		_upgrade_from_version_39(game)
	if version <= 40:
		_upgrade_from_version_40(game)
	if version <= 41:
		_upgrade_from_version_41(game)
	if version <= 42:
		_upgrade_from_version_42(game)


## Version 33 had no deed log (task 125): nothing was seen yet, and no villager has a story.
static func _upgrade_from_version_33(game: Dictionary) -> void:
	game["deeds"] = []
	for npc: Dictionary in game["npcs"]:
		npc["stories"] = []


## Version 34 had memories as plain lines and stories of the deed alone (task 126): the memories
## are of medium weight now, and of no known day; the stories were seen by the villager on the day
## of the deed, and weigh medium.
static func _upgrade_from_version_34(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		for story: Dictionary in npc["stories"]:
			story["how"] = "seen"
			story["told_by"] = ""
			story["seen_by"] = npc["name"]
			story["hops"] = 0
			story["learned"] = story["day"]
			story["line"] = ""
			story["weight"] = "medium"
			story["personal"] = false
		npc["memories"] = npc["memories"].map(
			func(text: String) -> Dictionary: return {"day": 0, "text": text, "weight": "medium"}
		)


## Version 35 had stories without an origin and learned on a day (task 127): a story is named by
## its deed as it is, and was learned at the minute of the deed's day.
static func _upgrade_from_version_35(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		for story: Dictionary in npc["stories"]:
			story["origin"] = "%d|%s|%s" % [story["day"], story["kind"], story["place"]]
			story["learned_at"] = (
				(int(story["learned"]) - 1) * GameClock.MINUTES_PER_DAY + int(story["minute"])
			)
			story.erase("learned")


## Version 36 had no opinion of the player (task 128): every villager starts at none, and the
## stories they know are judged (their opinion would be of days long gone).
static func _upgrade_from_version_36(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		for story: Dictionary in npc["stories"]:
			story["is_judged"] = true
		npc["opinion"] = 0
		npc["opinion_day"] = 0
		npc["opinion_moved_today"] = 0


## Version 37 had no topics of the village (task 129): the villagers of data/villagers.cfg know
## them all, as they did, and a made-up one starts with none.
static func _upgrade_from_version_37(game: Dictionary) -> void:
	# Written out, not read from data/village.cfg, so a later change leaves old saves alone.
	var all_topics := ["village", "places", "people", "money", "news", "calendar", "world"]
	for npc: Dictionary in game["npcs"]:
		npc["topics"] = all_topics.duplicate() if npc["id"] != "" else []


## Version 38 had no houses and workplaces for villagers (task 228): they have none, and keep the
## anchor they had.
static func _upgrade_from_version_38(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		npc["house"] = null
		npc["workplace"] = null


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


static func _give_lanterns_a_candle(data: Variant) -> void:
	if data is Array:
		for entry: Variant in data:
			_give_lanterns_a_candle(entry)
	elif data is Dictionary:
		if data.get("item") == "lantern" and data.get("count") == 1:
			data["state"] = {"candle": {}}
		for entry: Variant in data.values():
			_give_lanterns_a_candle(entry)
