class_name AssetCheck
extends RefCounted
## Whether every picture under assets/ can be loaded. A picture that is in the repo but not
## imported yet (the game was started without the editor or `--import` after new art came
## in) loads as nothing, which would show as an invisible house or object much later. Only
## run from source: an exported game has no source pictures to walk.

const ASSETS_DIR := "res://assets"
const HINT := "Run `make run`, or `godot --headless --import` once, to import new assets."


## The pictures under `directory` (and its folders) that can't be loaded.
static func missing(directory := ASSETS_DIR) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(directory):
		var path := directory.path_join(file)
		if file.get_extension() == "png" and not _is_skipped(path) and load(path) == null:
			found.append(path)
	for folder in DirAccess.get_directories_at(directory):
		found.append_array(missing(directory.path_join(folder)))
	return found


## Whether a picture is not imported on purpose (e.g. a font's page, which the font loads).
static func _is_skipped(path: String) -> bool:
	var import := ConfigFile.new()
	return (
		import.load(path + ".import") == OK and import.get_value("remap", "importer", "") == "skip"
	)


## Reports the pictures that can't be loaded; returns whether all can. Always true in an
## exported game.
static func report() -> bool:
	if OS.has_feature("template"):
		return true
	var paths := missing()
	for path in paths:
		push_error("Missing or not imported: %s" % path)
	if not paths.is_empty():
		push_error(HINT)
	return paths.is_empty()
