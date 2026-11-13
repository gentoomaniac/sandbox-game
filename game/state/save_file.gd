class_name SaveFile
extends RefCounted
## The save on disk: one JSON file per world, `{"version": VERSION, "game": <GameState.to_dict>}`.
## Saves from OLDEST_VERSION to VERSION (ten upgrade steps) still load, upgraded step by step
## (see `_upgrade_from_version_23` and so on). Older ones are refused.
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

const VERSION := 33
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
	if version <= 23:
		_upgrade_from_version_23(game)
	if version <= 24:
		_upgrade_from_version_24(game)
	if version <= 25:
		_upgrade_from_version_25(game)
	if version <= 26:
		_upgrade_from_version_26(game)
	if version <= 27:
		_upgrade_from_version_27(game)
	if version <= 28:
		_upgrade_from_version_28(game)
	if version <= 29:
		_upgrade_from_version_29(game)
	if version <= 30:
		_upgrade_from_version_30(game)
	if version <= 31:
		_upgrade_from_version_31(game)
	if version <= 32:
		_upgrade_from_version_32(game)


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


## Version 27 had no lantern (task 177): it is out.
static func _upgrade_from_version_27(game: Dictionary) -> void:
	game["player"]["is_lantern_lit"] = false


## Version 28 kept no items on the floors of interiors (task 200): nothing lies there.
static func _upgrade_from_version_28(game: Dictionary) -> void:
	for building: Dictionary in game["world"]["buildings"]:
		if building["interior"] != null:
			building["interior"]["ground_items"] = []


## Version 29 had no attributes (task 187): the player has the base level of each.
static func _upgrade_from_version_29(game: Dictionary) -> void:
	# Written out, not read from data/attributes.cfg, so a later change of a base level leaves
	# old saves alone.
	var base_level := 10
	game["player"]["attributes"] = {
		"levels":
		{"strength": base_level, "agility": base_level, "stamina": base_level, "hp": base_level}
	}


## Version 30 had no process stations (task 199): every kiln and oven gets an empty grid of 3x3,
## and a kiln's firing (`work`, a recipe and the minute it is done) becomes a run of the one
## Bricks recipe: its load in the grid and its bricks to come at the same minute.
static func _upgrade_from_version_30(game: Dictionary) -> void:
	# Written out, not read from the data files, which no longer have the old recipes.
	var grid_slots := 9
	var firing_minutes := 12 * GameClock.MINUTES_PER_HOUR
	var old_firings := {
		"bricks": {"raw_brick": 6, "logs": 2, "brick": 6},
		"bricks_large": {"raw_brick": 12, "logs": 3, "brick": 12},
		"bricks_master": {"raw_brick": 18, "logs": 3, "brick": 18},
	}
	var objects: Array = []
	for edit: Dictionary in game["world"]["object_edits"]:
		if edit["object"] != null:
			objects.append(edit["object"])
	for building: Dictionary in game["world"]["buildings"]:
		if building["interior"] != null:
			objects.append_array(building["interior"]["objects"])
	for object: Dictionary in objects:
		if object["type"] not in ["kiln", "oven"]:
			continue
		var grid := []
		grid.resize(grid_slots)
		object["storage"] = grid
		var state: Dictionary = object["state"]
		if not state.has("work"):
			continue
		var work: Dictionary = state["work"]
		state.erase("work")
		var firing: Dictionary = old_firings.get(work["recipe"], {})
		if firing.is_empty():
			continue
		grid[0] = {"item": "raw_brick", "count": firing["raw_brick"]}
		grid[1] = {"item": "logs", "count": firing["logs"]}
		var done := int(work["done_minute"])
		state["run"] = {
			"recipe": "bricks",
			"start_minute": done - firing_minutes,
			"done_minute": done,
			"products": {"brick": firing["brick"]},
		}


## Version 31 had no roosters as a rule (task 204): each flock of chickens (see ChickenFlocks) gets
## exactly one. A chicken of the rooster look, drawn as a random look, counts as its flock's
## rooster (the first of a flock does; the others become hens, brown), and a flock with none gets a
## new one standing where its first chicken does.
static func _upgrade_from_version_31(game: Dictionary) -> void:
	# Written out, not read from the data files, so a later change leaves old saves alone.
	var flock_tiles := 12.0
	var rooster_look := "rooster"
	var hen_look := "brown"
	var coop_type := "chicken_coop"
	var chickens: Array[Dictionary] = []
	for animal: Dictionary in game["livestock"]:
		if animal["species"] == "chicken":
			chickens.append(animal)
	var positions: Array[Vector2] = []
	for chicken in chickens:
		positions.append(SaveCodec.float_vector_from_json(chicken["position"]))
	# A coop is at the middle of its first tile, as Coop `roost_spot` has it.
	var coops: Array[Vector2] = []
	for building: Dictionary in game["world"]["buildings"]:
		if building["type"] == coop_type:
			coops.append(
				Vector2(SaveCodec.vector_from_json(building["origin"])) + Vector2(0.5, 0.5)
			)
	for flock in ChickenFlocks.groups(positions, coops, flock_tiles):
		var has_rooster := false
		for index in flock:
			if chickens[index]["look"] != rooster_look:
				continue
			if has_rooster:
				chickens[index]["look"] = hen_look
			has_rooster = true
		if not has_rooster:
			var rooster: Dictionary = chickens[flock[0]].duplicate()
			rooster["look"] = rooster_look
			rooster["tint"] = "ffffff"
			rooster["friendship"] = 0
			rooster["last_petted_day"] = 0
			rooster["last_petted_asleep_day"] = 0
			game["livestock"].append(rooster)


## Version 32 had one grade of each tool (task 207): they are the rusty iron ones now, wherever
## a stack of items is saved (the inventory, a chest, a station's grid, the ground), and in the
## held layer of the player's look.
static func _upgrade_from_version_32(game: Dictionary) -> void:
	# Written out, not read from the data files, so a later change leaves old saves alone.
	var tools := ["hoe", "axe", "pickaxe", "watering_can", "scythe", "shovel", "hammer"]
	_rename_tools(game, tools)


## Gives the rusty iron grade to the `tools` named by an `item` or a `variant` anywhere in saved
## data.
static func _rename_tools(data: Variant, tools: Array) -> void:
	if data is Array:
		for entry: Variant in data:
			_rename_tools(entry, tools)
	elif data is Dictionary:
		for key: String in data:
			if key in ["item", "variant"] and data[key] in tools:
				data[key] = "rusty_iron_" + data[key]
			else:
				_rename_tools(data[key], tools)
