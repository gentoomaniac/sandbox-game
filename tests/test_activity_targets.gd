extends GutTest
## The kinds of place an activity is done at (ActivityTarget): what is read from the folder, and
## that a kind that is not in it is a target like the others.


## A kind that is not in the folder: with a door, and looked for within `search_tiles` or not.
class InnTarget:
	extends ActivityTarget
	var is_a_search := false

	func kind() -> String:
		return "inn"

	func is_searched() -> bool:
		return is_a_search

	func has_door() -> bool:
		return true


## The real file with `work_changes` made to the activity `work`, and the inn among the kinds when
## `kinds` has it.
func _rules_with(kinds: Dictionary, work_changes: Dictionary) -> ActivityRules:
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values["work"].merge(work_changes, true)
	return ActivityRules.new(values, kinds)


func _kinds_with_inn(is_a_search: bool) -> Dictionary:
	var inn := InnTarget.new()
	inn.is_a_search = is_a_search
	var kinds := ActivityTargets.default_kinds().duplicate()
	kinds["inn"] = inn
	return kinds


func test_the_targets_are_the_kinds_of_the_folder() -> void:
	var kinds := ActivityTargets.default_kinds().keys()
	kinds.sort()
	assert_eq(kinds, ["church", "field", "friend", "home", "meeting", "wild", "workplace"] as Array)


func test_a_new_kind_is_a_target_that_may_have_a_door() -> void:
	var changes := {"target": "inn", "inside": true}
	assert_eq(_rules_with(_kinds_with_inn(false), changes).problems().size(), 0)
	var without_inn := _rules_with(ActivityTargets.default_kinds(), changes)
	assert_eq(without_inn.problems().size(), 1, "no such target")


func test_a_searched_kind_needs_its_search_tiles() -> void:
	assert_eq(_rules_with(_kinds_with_inn(true), {}).problems().size(), 1)
