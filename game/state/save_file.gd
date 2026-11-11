class_name SaveFile
extends RefCounted
## The save on disk: one JSON file per world, `{"version": VERSION, "game": <GameState.to_dict>}`.
## Saves from OLDEST_VERSION to VERSION (ten upgrade steps) still load, upgraded step by step
## (see `_upgrade_from_version_18` and so on). Older ones are refused.
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

const VERSION := 27
## The oldest version we still upgrade. Nine steps back, for the next version (task 177) makes
## its step the tenth.
const OLDEST_VERSION := VERSION - 9
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
	if version <= 18:
		_upgrade_from_version_18(game)
	if version <= 19:
		_upgrade_from_version_19(game)
	if version <= 20:
		_upgrade_from_version_20(game)
	if version <= 21:
		_upgrade_from_version_21(game)
	if version <= 22:
		_upgrade_from_version_22(game)
	if version <= 23:
		_upgrade_from_version_23(game)
	if version <= 24:
		_upgrade_from_version_24(game)
	if version <= 25:
		_upgrade_from_version_25(game)
	if version <= 26:
		_upgrade_from_version_26(game)


## Version 18 kept no more of who a villager is than their name, sex and look: each is given an
## age, trade and the rest made up from the tables of data/npcs.cfg, the same for the same name.
static func _upgrade_from_version_18(game: Dictionary) -> void:
	var rules := NpcRules.default_rules()
	for npc: Dictionary in game["npcs"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(npc["name"])
		npc.merge(rules.pick_sheet(StringName(npc["sex"]), npc["name"].get_slice(" ", 1), rng))
		npc["id"] = ""


## Version 19 kept no memories of villagers: they remember no conversation.
static func _upgrade_from_version_19(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		npc["memories"] = []
		npc["lines_since_memory"] = 0


## Version 20 made a memory when a chat was closed and counted the lines not in one yet
## (`lines_since_memory`); now the lines beyond the chat's length are made a memory. The lines a
## version 20 memory already holds stay in the chat but are `remembered_lines`: they drop out
## without being summed up again. The lines not in a memory are made one when they drop out.
static func _upgrade_from_version_20(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		var unremembered := mini(int(npc["lines_since_memory"]), npc["chat_history"].size())
		npc["remembered_lines"] = npc["chat_history"].size() - unremembered
		npc.erase("lines_since_memory")
		npc["uncompacted_lines"] = []


## Version 21 had no saddles: no horse wears one.
static func _upgrade_from_version_21(game: Dictionary) -> void:
	for animal: Dictionary in game["livestock"]:
		animal["is_saddled"] = false


## Version 22 kept a shorter sheet of who a villager is (task 96 made it longer). One written by
## hand needs nothing: a loaded villager of data/villagers.cfg takes their sheet from it (see Npc
## `from_dict`). A made-up one is made up anew from the tables of data/npcs.cfg, the same for the
## same name, as the old tables gave them English words to say ("Aye") and trades they no longer
## have; one with the surname of a family of the village sheet (Boysen, Hansen, ...) gets another,
## so that they are not taken for kin of that family.
static func _upgrade_from_version_22(game: Dictionary) -> void:
	var villagers := VillagerRules.default_rules()
	var rules := NpcRules.default_rules()
	var village := VillageSheet.default_sheet().text(true)
	for npc: Dictionary in game["npcs"]:
		if villagers.has(npc["id"]):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(npc["name"])
		var surname: String = npc["name"].get_slice(" ", 1)
		if village.contains(surname):
			surname = rules.pick_surname(rng)
			npc["name"] = "%s %s" % [npc["name"].get_slice(" ", 0), surname]
		npc.merge(rules.pick_sheet(StringName(npc["sex"]), surname, rng), true)


## Version 23 had no styles of buildings (task 120): every building has its own look.
static func _upgrade_from_version_23(game: Dictionary) -> void:
	for building: Dictionary in game["world"]["buildings"]:
		building["style"] = ""


## Version 24 had no water in the watering can and no hunger or thirst of the farm animals (task
## 122): the can is full and the animals have just eaten and drunk.
static func _upgrade_from_version_24(game: Dictionary) -> void:
	game["player"]["can_water"] = EnergyRules.default_rules().can_capacity()
	for animal: Dictionary in game["livestock"]:
		animal["hunger"] = 0.0
		animal["thirst"] = 0.0


## Version 25 had no fallow soil (task 166): every tilled tile was tended on the night of the
## upgrade, and its days count from there.
static func _upgrade_from_version_25(game: Dictionary) -> void:
	var world: Dictionary = game["world"]
	var fallow_soil: Array[Array] = []
	for edit: Array in world["terrain_edits"]:
		if SaveCodec.terrain_from_json(edit[2]) == Tile.Terrain.SOIL:
			fallow_soil.append([edit[0], edit[1], 0])
	world["fallow_nights"] = 0
	world["fallow_soil"] = fallow_soil


## Version 26 had no friendship (task 173): every animal is a stranger, never petted.
static func _upgrade_from_version_26(game: Dictionary) -> void:
	for animal: Dictionary in game["livestock"]:
		animal["friendship"] = 0
		animal["last_petted_day"] = 0
		animal["last_petted_asleep_day"] = 0
