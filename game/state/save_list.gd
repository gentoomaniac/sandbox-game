class_name SaveList
extends RefCounted
## The saves of one world. Every save is a new file: for the world's save path `world.json`
## they are `world.000001.json`, `world.000002.json` and so on, and the newest ones are kept (the
## number is in data/saves.cfg). A `world.json` itself, as the game used to keep its one save, is
## the oldest of them. A save's header is in a file beside it, `world.000001.json.info`
## (see SaveHeader). The backups of saves that can't be used (`.bak`, see SaveFile
## `free_backup_path`) are not part of the list.

const CONFIG_PATH := "res://data/saves.cfg"
const HEADER_SUFFIX := ".info"
## Wide enough that the files of a long game still sort by number.
const NUMBER_DIGITS := 6


## How many saves are kept.
static func kept_count() -> int:
	var sections := DataFile.read_sections(CONFIG_PATH)
	return maxi(1, int(sections["keep"]["saves"]))


static func header_path_of(save_path: String) -> String:
	return save_path + HEADER_SUFFIX


## The path of the next save of the world at `base`: one number past the newest.
static func next_path(base: String) -> String:
	var number := 1
	for save_path in paths_newest_first(base):
		number = maxi(number, _number_of(base, save_path) + 1)
	return _path_numbered(base, number)


## The files of the saves of the world at `base`, the newest first, the old single save last.
static func paths_newest_first(base: String) -> Array[String]:
	var paths: Array[String] = []
	# Before the first save there is no folder, and listing a missing one is an engine error.
	if not DirAccess.dir_exists_absolute(base.get_base_dir()):
		return paths
	var numbered := {}
	for file_name in DirAccess.get_files_at(base.get_base_dir()):
		var save_path := base.get_base_dir().path_join(file_name)
		var number := _number_of(base, save_path)
		if number > 0:
			numbered[number] = save_path
	var numbers := numbered.keys()
	numbers.sort()
	numbers.reverse()
	for number: int in numbers:
		paths.append(numbered[number])
	if FileAccess.file_exists(base):
		paths.append(base)
	return paths


## The newest save of the world at `base`, or "" if there is none.
static func newest_path(base: String) -> String:
	var paths := paths_newest_first(base)
	return "" if paths.is_empty() else paths[0]


## Deletes the saves (and their headers) beyond the newest `kept_count()`.
static func prune(base: String) -> void:
	for save_path in paths_newest_first(base).slice(kept_count()):
		remove(save_path)


## Deletes a save and its header.
static func remove(save_path: String) -> void:
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(header_path_of(save_path))


## The saves of the world at `base`, the newest first, each with its header, or why it can't be
## loaded. A save without a header (the old single one) gets one made of its own data, once.
static func entries(base: String) -> Array[SaveEntry]:
	var found: Array[SaveEntry] = []
	for save_path in paths_newest_first(base):
		found.append(_entry_of(save_path))
	return found


static func _entry_of(save_path: String) -> SaveEntry:
	var header_path := header_path_of(save_path)
	var header: SaveHeader = null
	if FileAccess.file_exists(header_path):
		header = SaveHeader.from_text(FileAccess.get_file_as_string(header_path))
	if header == null:
		header = _header_made_of(save_path)
	if header == null:
		return SaveEntry.new(save_path, null, "not a save file")
	if not header.is_version_supported():
		var why := "save version %d, this game reads versions %d to %d"
		return SaveEntry.new(
			save_path, header, why % [header.version, SaveFile.OLDEST_VERSION, SaveFile.VERSION]
		)
	return SaveEntry.new(save_path, header)


## Reads the whole save to make its header, and keeps it for the next time.
static func _header_made_of(save_path: String) -> SaveHeader:
	var json := JSON.new()
	# Not parse_string: it prints an engine error of its own for broken text.
	if json.parse(FileAccess.get_file_as_string(save_path)) != OK or not json.data is Dictionary:
		return null
	var header := SaveHeader.of_earlier_save(
		json.data.get("game"), json.data.get("version"), FileAccess.get_modified_time(save_path)
	)
	if header != null:
		SaveFile.write_text(header.to_text(), header_path_of(save_path))
	return header


static func _path_numbered(base: String, number: int) -> String:
	var stem := base.get_basename()
	return "%s.%0*d.%s" % [stem, NUMBER_DIGITS, number, base.get_extension()]


## The number in the name of `save_path` as a save of the world at `base`, or 0 if it is not one
## (the file `base` itself, a header, a backup).
static func _number_of(base: String, save_path: String) -> int:
	var prefix := base.get_file().get_basename() + "."
	var suffix := "." + base.get_extension()
	var file_name := save_path.get_file()
	if not (file_name.begins_with(prefix) and file_name.ends_with(suffix)):
		return 0
	var digits := file_name.trim_prefix(prefix).trim_suffix(suffix)
	var is_number := digits != "" and digits.lstrip("0123456789") == ""
	return int(digits) if is_number else 0
