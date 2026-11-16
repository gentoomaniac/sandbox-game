class_name QuestKinds
extends RefCounted
## The kinds of objective and of prerequisite a quest can have. Each kind is one script in a folder
## of its own (game/state/quests/objectives, game/state/quests/conditions); a new kind is a new
## file there and no other code. A script that does not load, extends no `base` or has no kind or
## one that another has is a problem for the caller to report, not one to skip silently.

const OBJECTIVES_DIR := "res://game/state/quests/objectives"
const CONDITIONS_DIR := "res://game/state/quests/conditions"


## One instance of each kind of the scripts in `directory` that extend `base`, by the kind's name.
## `ResourceLoader` lists the resources, so this works in an exported game too. What is wrong with
## a script is added to `problems`, and that script gives no kind.
static func in_folder(directory: String, base: GDScript, problems: Array[String]) -> Dictionary:
	var kinds := {}
	for path in ScriptFolder.paths(directory):
		var script := load(path) as GDScript if ResourceLoader.exists(path) else null
		if script == null or not _extends(script, base):
			problems.append("%s is no script that extends %s" % [path, base.get_global_name()])
			continue
		var kind: Object = script.new()
		var name: String = kind.kind()
		if name.is_empty():
			problems.append("%s has no kind" % path)
		elif kinds.has(name):
			problems.append("%s: %s is also the kind of another script" % [path, name])
		else:
			kinds[name] = kind
	return kinds


static func _extends(script: GDScript, base: GDScript) -> bool:
	var current := script.get_base_script()
	while current != null:
		if current == base:
			return true
		current = current.get_base_script()
	return false
