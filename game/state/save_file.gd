class_name SaveFile
extends RefCounted
## The save on disk: one JSON file per world, `{"version": 2, "game": <GameState.to_dict>}`.
## Version 1 saves still load: they had a harvest count instead of an inventory.

const VERSION := 2
const DEFAULT_PATH := "user://saves/world.json"
## What a save we can't use is renamed to, so it is never overwritten silently.
const BACKUP_SUFFIX := ".bak"


## Writes the game to `path`. Returns whether it worked.
static func write(state: GameState, path: String = DEFAULT_PATH) -> bool:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		push_error("Can't create the save folder: %s" % error_string(error))
		return false
	# Written beside the save and renamed over it, so a crash never leaves half a save.
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Can't write %s: %s" % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify({"version": VERSION, "game": state.to_dict()}, "\t"))
	file.close()
	error = DirAccess.rename_absolute(temp_path, path)
	if error != OK:
		push_error("Can't replace %s: %s" % [path, error_string(error)])
		return false
	return true


## The saved game, or null if there is no save. A save that can't be read (broken, or from
## another version) is reported, moved aside to `<path>.bak` and also gives null: the caller
## starts a new game.
static func read(path: String = DEFAULT_PATH) -> GameState:
	if not FileAccess.file_exists(path):
		return null
	# Not parse_string: it prints an engine error of its own for broken text.
	var json := JSON.new()
	var parsed: Variant = (
		json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	)
	if not parsed is Dictionary:
		_reject(path, "not a save file")
		return null
	# `==` also accepts the 1.0 that JSON parsing gives.
	var version: Variant = parsed.get("version")
	if version != 1 and version != VERSION:
		_reject(path, "save version %s, this game reads versions 1 and %d" % [version, VERSION])
		return null
	if not parsed.has("game"):
		_reject(path, "no game in the save")
		return null
	if version == 1:
		_upgrade_from_version_1(parsed["game"])
	return GameState.from_dict(parsed["game"])


## Version 1 had no inventory, only the number of crops harvested: that is now turnips in the
## starting inventory.
static func _upgrade_from_version_1(game: Dictionary) -> void:
	var inventory := Inventory.with_starting_items()
	inventory.add(ItemTypes.TURNIP, int(game["harvest_count"]))
	game.erase("harvest_count")
	game["player"]["inventory"] = inventory.to_dict()


static func _reject(path: String, reason: String) -> void:
	var backup := path + BACKUP_SUFFIX
	push_error(
		"Can't load %s (%s). Moving it to %s and starting a new game." % [path, reason, backup]
	)
	DirAccess.rename_absolute(path, backup)
