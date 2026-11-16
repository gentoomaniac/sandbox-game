extends ActivityCase
## The kinds of place an activity is done at (ActivityTarget): what is read from the folder, and
## that a kind that is not in it is a target like the others, with no change to the scheduler.

const INN_SPOT := Vector2(70.5, 70.5)


## A kind that is not in the folder: an inn with a door, at one spot, looked for within
## `search_tiles` or not.
class InnTarget:
	extends ActivityTarget
	var is_a_search := false

	func kind() -> String:
		return "inn"

	func is_searched() -> bool:
		return is_a_search

	func has_door() -> bool:
		return true

	func spot_of(_npc: Npc, _day: int, _places: ActivityPlaces) -> Vector2:
		return INN_SPOT


## The real file with `work_changes` made to the activity `work`, the inn among the kinds, and,
## when `has_beer`, an activity at the inn every evening for everybody.
func _rules_with(is_a_search: bool, work_changes := {}, has_beer := false) -> ActivityRules:
	var inn := InnTarget.new()
	inn.is_a_search = is_a_search
	var kinds := ActivityTargets.default_kinds().duplicate()
	kinds["inn"] = inn
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values["work"].merge(work_changes, true)
	if has_beer:
		values["have_a_beer"] = {
			"verb": "have a beer", "target": "inn", "doing": "stand", "at": [["19:00", 60]]
		}
		values["sets"]["base"].append("have_a_beer")
	return ActivityRules.new(values, kinds)


func test_the_targets_are_the_kinds_of_the_folder() -> void:
	var kinds := ActivityTargets.default_kinds().keys()
	kinds.sort()
	assert_eq(kinds, ["church", "field", "friend", "home", "meeting", "wild", "workplace"] as Array)


func test_a_new_kind_is_a_target_that_may_have_a_door() -> void:
	assert_eq(_rules_with(false, {"target": "inn", "inside": true}).problems().size(), 0)
	assert_eq(_rules_with(true).problems().size(), 1, "a searched kind needs its search tiles")


func test_an_activity_at_a_new_kind_is_planned_and_walked_to_by_the_same_scheduler() -> void:
	var rules := _rules_with(false, {}, true)
	assert_eq(rules.problems(), [] as Array[String])
	var upkeep := ActivityUpkeep.new(
		_world, _npcs, _state.homes, _state.sun, _state.weather, _state.clock, rules
	)
	var npc := _resident("hinrich")
	var planned: Array[String] = []
	for entry in upkeep.entries_of(npc, DAY):
		planned.append(entry.activity)
	assert_has(planned, "have_a_beer")
	var offered: Array[String] = []
	for offer in upkeep.offers_of(npc, DAY):
		offered.append(offer["id"])
	assert_has(offered, "have_a_beer")
	_set_time(DAY, 18, 30)
	var step := upkeep.next_step_of(npc)
	assert_eq(step.activity, "have_a_beer")
	assert_eq(step.spot, INN_SPOT)
