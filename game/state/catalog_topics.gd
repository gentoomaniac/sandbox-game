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
## script that does not load, has no `TYPES` or has `TYPES` that are no table gives none, and a
## definition of the wrong shape (id not a StringName, value not a table, key not a text) is left
## out; each is added to `problems` with the script's path.
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
		var types = constants[TYPES_CONSTANT]
		if not types is Dictionary:
			problems.append("%s: %s must be a table of ids" % [path, TYPES_CONSTANT])
			continue
		by_path[path] = _well_formed(path, types, problems)
	return by_path


## All the definitions of `types_by_source` (the source's name, a path, to its types) as one
## table. `kind` is "item" or "object". An id that two sources define is added to `problems` as
## "<kind> <id>: defined in <first> and in <second>", and the first source's definition is kept.
## `reserved_by` (id to the name of what makes it later) holds ids that no source may define: they
## count as defined by that name before the first source, so a clash is a problem naming the source.
static func merged(
	kind: String, types_by_source: Dictionary, problems: Array[String], reserved_by := {}
) -> Dictionary:
	var all_types := {}
	var source_of := reserved_by.duplicate()  # id -> the source that defines it
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


static func _well_formed(path: String, types: Dictionary, problems: Array[String]) -> Dictionary:
	var kept := {}
	for id in types:
		var definition = types[id]
		if not id is StringName:
			problems.append('%s: id %s must be a StringName (&"name")' % [path, id])
		elif not definition is Dictionary:
			problems.append("%s: %s must be a table" % [path, id])
		elif definition.keys().any(func(key): return not key is String):
			problems.append("%s: %s has a key that is no text" % [path, id])
		else:
			kept[id] = definition
	return kept
