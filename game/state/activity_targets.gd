class_name ActivityTargets
extends RefCounted
## The kinds of place an activity can be done at, one script each in game/state/activity_targets
## (see ActivityTarget). They are loaded by KindFolder.

const DIR := "res://game/state/activity_targets"

static var _default: Dictionary


## One instance of each kind in the folder, by the kind's name, loaded the first time they are asked
## for. A script that is no kind is reported with a `push_error`.
static func default_kinds() -> Dictionary:
	if _default.is_empty():
		var problems: Array[String] = []
		_default = KindFolder.in_folder(DIR, ActivityTarget, problems)
		for problem in problems:
			push_error(problem)
	return _default
