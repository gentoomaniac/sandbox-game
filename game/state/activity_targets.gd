class_name ActivityTargets
extends RefCounted
## The kinds of place an activity can be done at, one script each in game/state/activity_targets
## (see ActivityTarget). They are loaded by KindFolder, and what is wrong with the scripts is for
## ActivityRules to report, so that the game does not start with a kind missing.

const DIR := "res://game/state/activity_targets"

static var _default: Dictionary
static var _default_problems: Array[String] = []


## One instance of each kind in the folder, by the kind's name, loaded the first time they are asked
## for.
static func default_kinds() -> Dictionary:
	if _default.is_empty():
		_default = KindFolder.in_folder(DIR, ActivityTarget, _default_problems)
	return _default


## What is wrong with the scripts of the folder (see KindFolder).
static func default_problems() -> Array[String]:
	default_kinds()
	return _default_problems
