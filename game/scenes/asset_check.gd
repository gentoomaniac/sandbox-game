class_name AssetCheck
extends RefCounted
## Whether every picture under assets/ can be loaded, and every item and object has the pictures
## it names. A picture that is in the repo but not imported yet (the game was started without the
## editor or `--import` after new art came in) loads as nothing, which would show as an invisible
## house or object much later. Only run from source: an exported game has no source pictures to
## walk.

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


## What of the pictures that items and world objects name can't be loaded, in either art set,
## as "item <id>: ..." and "object <id>: ...". An object with an atlas row needs the row and as
## many cells as its looks in the atlas.
static func catalog_problems(items: Dictionary, objects: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for classic in [false, true]:
		var art := "classic art" if classic else "new art"
		var atlas: Texture2D = load(ArtSet.path_in(ObjectTileset.ATLAS_PATH, classic))
		for id: StringName in items:
			var paths := [ItemTypes.icon_path(id), ItemTypes.ground_icon_path(id)]
			for path: String in paths:
				if not _can_load(ArtSet.path_in(path, classic)):
					found.append("item %s: no picture %s in the %s" % [id, path, art])
		for id: StringName in objects:
			var object: Dictionary = objects[id]
			var paths: Array = []
			for key in ["interior_sprite", "object_cover", "interior_cover", "sheet"]:
				paths.append_array([object[key]] if object.has(key) else [])
			for path: String in paths:
				if not _can_load(ArtSet.path_in(path, classic)):
					found.append("object %s: no picture %s in the %s" % [id, path, art])
			if object.has("atlas_row") and not _atlas_has_cells(atlas, object):
				found.append(
					(
						"object %s: the %s atlas has no row %d with its looks"
						% [id, art, object["atlas_row"]]
					)
				)
	return found


## Whether the picture is there and imported (asking `load` of one that is not there is an
## engine error).
static func _can_load(path: String) -> bool:
	return ResourceLoader.exists(path) and load(path) != null


## Whether the atlas has the row of the type, with the cells of all its looks.
static func _atlas_has_cells(atlas: Texture2D, object: Dictionary) -> bool:
	if atlas == null:
		return false
	var cells_wide: int = object.get("cells_wide", 1)
	var looks := ObjectTileset.looks_count(object) * cells_wide
	return (
		atlas.get_height() >= (object["atlas_row"] + 1) * ObjectTileset.CELL_HEIGHT
		and atlas.get_width() >= looks * ObjectTileset.CELL_WIDTH
	)


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
	var catalog := catalog_problems(ItemTypes.TYPES, WorldObjectTypes.TYPES)
	for problem in catalog:
		push_error(problem)
	if not paths.is_empty() or not catalog.is_empty():
		push_error(HINT)
	return paths.is_empty() and catalog.is_empty()
