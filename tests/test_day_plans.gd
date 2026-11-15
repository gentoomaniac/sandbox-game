extends ActivityCase
## The plan of the language model on the villager (DayPlan, `Npc.day_plans`): it replaces the
## default day, a plan for the rest of the day keeps the default entries before it, it takes over
## from the minute it comes, and old ones are dropped.


func _entry(activity: String, hour: int, minute := 0, why := "") -> DayEntry:
	return DayEntry.new(activity, hour * 60 + minute, 0, why)


func _plan(day: int, entries: Array[DayEntry], is_whole_day := true) -> DayPlan:
	var made_at := (day - 1) * GameClock.MINUTES_PER_DAY + 12 * 60
	return DayPlan.new(day, entries, is_whole_day, made_at)


func _activities_of(entries: Array[DayEntry]) -> Array[String]:
	var activities: Array[String] = []
	for entry in entries:
		activities.append("%02d:%02d %s" % [entry.minute / 60, entry.minute % 60, entry.activity])
	return activities


func test_a_plan_over_the_whole_day_replaces_the_default_day() -> void:
	var npc := _resident("hinrich")
	var entries: Array[DayEntry] = [_entry("breakfast", 5), _entry("sleep", 21)]
	_upkeep.set_plan(npc, _plan(DAY, entries))
	assert_eq(_upkeep.entries_of(npc, DAY), entries)
	assert_ne(_upkeep.entries_of(npc, DAY + 1), entries, "another day is the default day")


func test_a_plan_for_the_rest_of_the_day_keeps_the_default_entries_before_it() -> void:
	var npc := _resident("hinrich")
	var plan_entries: Array[DayEntry] = [_entry("rest", 14, 30), _entry("supper", 18)]
	var default_day := _activities_of(_upkeep.entries_of(npc, DAY))
	_upkeep.set_plan(npc, _plan(DAY, plan_entries, false))

	var before := default_day.filter(func(entry: String) -> bool: return entry < "14:30")
	var expected: Array[String] = []
	expected.assign(before)
	expected.append_array(["14:30 rest", "18:00 supper"])
	assert_eq(_activities_of(_upkeep.entries_of(npc, DAY)), expected)
	assert_gt(before.size(), 2, "some of the default day stays")


func test_the_plan_takes_over_from_the_minute_it_comes() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 12, 30)
	_pass_minutes(1)
	assert_eq(npc.current_step.activity, "dinner")

	var entries: Array[DayEntry] = [_entry("rest", 12, 31, "a walk after dinner")]
	_upkeep.set_plan(npc, _plan(DAY, entries, false))

	assert_eq(npc.current_step.activity, "rest", "at once, with no minute passing")
	assert_eq(_upkeep.entry_on(npc).why, "a walk after dinner")
	assert_null(npc.trip, "at home already: nobody walks")


func test_the_villager_is_sent_to_what_is_on_when_the_plan_comes() -> void:
	_build_warm_road()
	var npc := _resident("hinrich")
	npc.workplace = Workplace.of_spot("the landing", _road_tile(40))
	_set_time(DAY, 12, 30)
	_pass_minutes(1)
	var entries: Array[DayEntry] = [_entry("work", 12, 31), _entry("supper", 18)]
	_upkeep.set_plan(npc, _plan(DAY, entries, false))
	assert_eq(npc.current_step.activity, "work")
	assert_not_null(npc.trip, "on its way from where they stand")
	assert_eq(npc.trip.goal, npc.workplace.spot_tile)


func test_a_plan_that_has_them_do_what_they_do_sends_them_nowhere() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 12, 30)
	_pass_minutes(1)
	var step := npc.current_step
	var default_dinner := _entry_of(npc, DAY, "dinner")
	var entries: Array[DayEntry] = [
		DayEntry.new("dinner", default_dinner.minute), _entry("sleep", 21)
	]
	_upkeep.set_plan(npc, _plan(DAY, entries, false))
	assert_same(npc.current_step, step)


func test_tomorrow_s_plan_is_the_day_when_it_comes() -> void:
	var npc := _resident("hinrich")
	var entries: Array[DayEntry] = [_entry("breakfast", 5), _entry("rest", 7), _entry("sleep", 21)]
	_set_time(DAY, 22)
	_upkeep.set_plan(npc, _plan(DAY + 1, entries))
	_set_time(DAY + 1, 7, 30)
	assert_eq(_upkeep.entry_on(npc).activity, "rest")
	_pass_minutes(1)
	assert_eq(npc.current_step.activity, "rest")


func test_plans_of_days_before_yesterday_are_dropped() -> void:
	var npc := _resident("hinrich")
	var entries: Array[DayEntry] = [_entry("breakfast", 5)]
	for day in [DAY - 3, DAY - 2, DAY - 1, DAY, DAY + 1]:
		npc.day_plans[day] = _plan(day, entries)
	_set_time(DAY, 12)
	_pass_minutes(1)
	assert_eq(
		npc.day_plans.keys(), [DAY - 1, DAY, DAY + 1], "yesterday's stays for the next prompt"
	)


func test_a_villager_with_no_plan_has_the_default_day() -> void:
	_world.set_terrain(Vector2i(_house.yard().floor()) + Vector2i(0, 5), Tile.Terrain.SOIL)
	var npc := _resident("hinrich")
	assert_true(npc.day_plans.is_empty())
	var rules := ActivityRules.default_rules()
	var activities := VillagerActivities.of(npc, _npcs.villagers, _npcs.rules, rules)
	var default_day := DefaultDay.of(npc, activities, DAY, _world.world_seed, rules)
	assert_eq(_activities_of(_upkeep.entries_of(npc, DAY)), _activities_of(default_day))


# --- DayPlan ---


func test_over_gives_its_own_entries_for_the_whole_day() -> void:
	var entries: Array[DayEntry] = [_entry("breakfast", 5)]
	var default_day: Array[DayEntry] = [_entry("sleep", 1)]
	assert_eq(_plan(DAY, entries).over(default_day), entries)


func test_over_puts_a_part_after_the_default_entries_that_start_before_it() -> void:
	var entries: Array[DayEntry] = [_entry("rest", 14, 30)]
	var default_day: Array[DayEntry] = [
		_entry("breakfast", 5),
		_entry("work", 14, 29),
		_entry("supper", 14, 30),
		_entry("sleep", 21)
	]
	var merged := _plan(DAY, entries, false).over(default_day)
	assert_eq(
		_activities_of(merged), ["05:00 breakfast", "14:29 work", "14:30 rest"] as Array[String]
	)
