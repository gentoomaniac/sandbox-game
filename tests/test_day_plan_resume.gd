extends DayPlannerCase
## A loaded game resumes the plans of the villagers' days where they were (ActivityUpkeep `resume`):
## each is sent to the entry that is on, from where they stand, the model is not asked again for a
## day it planned, and a plan of days gone by is dropped.

var _loaded: GameState


func _plan(day: int, entries: Array[DayEntry]) -> DayPlan:
	return DayPlan.new(day, entries, true, (day - 1) * GameClock.MINUTES_PER_DAY + 18 * 60)


## The game saved and loaded again, its villagers' houses being the same buildings.
func _save_and_load() -> void:
	_loaded = GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))


func _plan_with_a_late_supper() -> Array[DayEntry]:
	return [
		DayEntry.new("breakfast", 6 * 60),
		DayEntry.new("supper", 12 * 60, 0, "a late supper"),
		DayEntry.new("sleep", 21 * 60),
	]


func test_a_plan_is_resumed_in_the_entry_that_is_on() -> void:
	var npc := _resident("hinrich")
	npc.day_plans[DAY] = _plan(DAY, _plan_with_a_late_supper())
	_set_time(DAY, 12, 30)
	_save_and_load()

	var loaded := _loaded.npcs.all()[0]

	assert_eq(loaded.current_step.activity, "supper", "the default day has dinner at this hour")
	assert_eq(_loaded.activities.entry_on(loaded).why, "a late supper")
	assert_null(loaded.trip, "at home already: nobody walks")


func test_a_villager_away_from_the_place_of_the_entry_is_sent_there_from_where_they_stand() -> void:
	var npc := _resident("hinrich")
	npc.day_plans[DAY] = _plan(DAY, _plan_with_a_late_supper())
	npc.position = _house.yard() + Vector2(6.0, 0.0)
	_set_time(DAY, 12, 30)
	_save_and_load()

	var loaded := _loaded.npcs.all()[0]

	assert_eq(loaded.current_step.activity, "supper")
	assert_eq(loaded.position, npc.position, "nobody jumps")
	assert_not_null(loaded.trip, "one search, from where they stand")


func test_a_plan_is_not_asked_for_again_after_a_load() -> void:
	var npc := _resident("hinrich")
	npc.day_plans[DAY] = _plan(DAY, _plan_with_a_late_supper())
	_set_time(DAY, 12, 30)
	_save_and_load()
	var planner := DayPlanner.new(_dialogue, _loaded)
	add_child_autoqfree(planner)
	_loaded.player.position = _house.yard()

	planner.queue_newcomers()
	await planner.ask_queue()

	assert_eq(_chat.requests.size(), 0)


func test_a_plan_of_days_gone_by_is_dropped_and_yesterdays_stays() -> void:
	var npc := _resident("hinrich")
	npc.day_plans[DAY - 3] = _plan(DAY - 3, _plan_with_a_late_supper())
	npc.day_plans[DAY - 1] = _plan(DAY - 1, _plan_with_a_late_supper())
	_set_time(DAY, 12, 30)
	_save_and_load()

	var loaded := _loaded.npcs.all()[0]

	assert_eq(loaded.day_plans.keys(), [DAY - 1])
	assert_eq(_loaded.activities.entry_on(loaded).activity, "dinner", "the default day")


func test_a_villager_who_comes_into_the_world_is_sent_on_their_day_at_once() -> void:
	_set_time(DAY, 12, 30)

	var kerrin := _npcs.spawn_villager("kerrin", _house.yard(), _world)

	assert_eq(kerrin.house, _house)
	assert_eq(kerrin.current_step.activity, "dinner", "not left for the next minute's tick")
