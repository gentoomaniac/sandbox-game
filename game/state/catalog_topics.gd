class_name CatalogTopics
extends RefCounted
## The definitions of items and of world objects, gathered from topic scripts: each script of a
## folder (game/state/items, game/state/world_objects) has a constant `TYPES` of the ids it
## defines, so a new ordinary item or object is an entry in a topic script and no other code.
## The definitions are plain data keyed by raw ids, so a topic does not depend on the table that
## gathers it. They are checked before they are merged: an id two topics define is a problem
## naming both, and neither definition is dropped silently.

const TYPES_CONSTANT := "TYPES"


## The `TYPES` of each script in `directory`, by the script's path, in the order of the paths. A
## script that does not load or has no `TYPES` is added to `problems` and gives none.
static func read_folder(directory: String, problems: Array[String]) -> Dictionary:
	var by_path := {}
	for path in ScriptFolder.paths(directory):
		var script := load(path) as GDScript if ResourceLoader.exists(path) else null
		if script == null:
			problems.append("%s cannot be loaded" % path)
			continue
		var constants := script.get_script_constant_map()
		if not constants.has(TYPES_CONSTANT):
			problems.append("%s has no %s" % [path, TYPES_CONSTANT])
			continue
		by_path[path] = constants[TYPES_CONSTANT]
	return by_path


## All the definitions of `types_by_source` (the source's name, a path, to its types) as one
## table. `kind` is "item" or "object". An id that two sources define is added to `problems` as
## "<kind> <id>: defined in <first> and in <second>", and the first source's definition is kept.
static func merged(
	kind: String, types_by_source: Dictionary, problems: Array[String]
) -> Dictionary:
	var all_types := {}
	var source_of := {}  # id -> the source that defines it
	for source: String in types_by_source:
		var types: Dictionary = types_by_source[source]
		for id: StringName in types:
			if source_of.has(id):
				problems.append(
					"%s %s: defined in %s and in %s" % [kind, id, source_of[id], source]
				)
				continue
			source_of[id] = source
			all_types[id] = types[id]
	return all_types
