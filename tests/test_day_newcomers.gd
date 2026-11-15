extends DayPlannerCase
## The villagers who come into the planning radius while the player moves (DayPlanner
## `queue_newcomers`): each is asked once for the rest of the current day, in the background, up to
## the most a day, and the plan takes over from the minute it comes. The model is a fake (FakeChat).


func before_each() -> void:
	super()
	_chat.answers = [REST_OF_DAY_ANSWER]
	_set_time(DAY, 13, 0)


## Lets a minute pass for the planner's look, and asks what it has queued.
func _look_next_minute() -> void:
	_state.clock.minute_of_day += 1
	_planner.queue_newcomers()
	await _planner.ask_queue()


func test_a_villager_in_the_radius_with_no_plan_is_asked_for_the_rest_of_today() -> void:
	var npc := _resident("hinrich")
	await _look_next_minute()
	assert_eq(_chat.requests.size(), 1)
	assert_string_contains(_chat.requests[0]["messages"][1]["content"], "It is 13:01 now")
	assert_false(npc.day_plans[DAY].is_whole_day)
	assert_eq(_chat.quiet_flags, [true] as Array[bool])


func test_with_day_plans_switched_off_a_newcomer_is_not_asked() -> void:
	var npc := _resident("hinrich")
	_settings.profiles.set_uses_model_for(&"day_plans", false)
	await _look_next_minute()
	assert_eq(_chat.requests.size(), 0)
	assert_false(npc.asked_plans.has(DAY))


func test_a_villager_is_asked_once_for_the_day() -> void:
	_resident("hinrich")
	await _look_next_minute()
	await _look_next_minute()
	await _look_next_minute()
	assert_eq(_chat.requests.size(), 1)


func test_a_villager_who_came_to_nothing_is_not_asked_again_that_day() -> void:
	var npc := _resident("hinrich")
	_chat.answers = ["no idea"]
	await _look_next_minute()
	await _look_next_minute()
	assert_eq(_chat.requests.size(), 1)
	assert_eq(npc.asked_plans[DAY], DayPlan.FAILED)
	_set_time(DAY + 1, 7)
	await _look_next_minute()
	assert_eq(_chat.requests.size(), 2, "a new day is a new question")


func test_a_villager_with_a_plan_for_today_is_not_asked() -> void:
	var npc := _resident("hinrich")
	var entries: Array[DayEntry] = [DayEntry.new("sleep", 21 * 60)]
	npc.day_plans[DAY] = DayPlan.new(DAY, entries, true, 0)
	await _look_next_minute()
	assert_eq(_chat.requests.size(), 0)


func test_a_villager_beyond_the_radius_is_asked_when_they_come_into_it() -> void:
	var npc := _resident_at("hinrich", 150.0)
	await _look_next_minute()
	assert_eq(_chat.requests.size(), 0)
	npc.position = _state.player.position + Vector2(100.0, 0.0)
	await _look_next_minute()
	assert_eq(_chat.requests.size(), 1)


func test_the_look_is_taken_once_a_game_minute() -> void:
	var npc := _resident("hinrich")
	_chat.answers = ["no idea"]
	_planner.queue_newcomers()
	npc.asked_plans.clear()
	_planner.queue_newcomers()
	assert_false(npc.asked_plans.has(DAY), "the same minute is not looked at twice")


func test_at_most_the_most_a_day_are_queued_and_the_rest_wait_for_another_day() -> void:
	_with_plan_value("max_per_day", 2)
	var first := _resident_at("hinrich", 3.0)
	var second := _resident_at("antje", 6.0)
	var third := _resident_at("momme", 9.0)
	await _look_next_minute()
	await _look_next_minute()
	assert_eq(_asked_names(), [first.name, second.name] as Array[String])
	assert_false(third.asked_plans.has(DAY))
	var entries: Array[DayEntry] = [DayEntry.new("sleep", 21 * 60)]
	for planned in [first, second]:
		planned.day_plans[DAY + 1] = DayPlan.new(DAY + 1, entries, true, 0)
	_set_time(DAY + 1, 7)
	await _look_next_minute()
	assert_eq(_asked_names()[2], third.name)


func test_the_nearest_to_the_player_now_is_asked_first_and_the_order_is_looked_at_again() -> void:
	var east := _resident_at("hinrich", 10.0)
	var west := _resident_at("antje", -20.0)
	_state.clock.minute_of_day += 1
	_planner.queue_newcomers()
	_state.player.position += Vector2(-30.0, 0.0)
	await _planner.ask_queue()
	assert_eq(_asked_names(), [west.name, east.name] as Array[String])


func test_one_who_has_left_the_radius_before_their_turn_is_dropped_and_asked_when_back() -> void:
	var npc := _resident("hinrich")
	_state.clock.minute_of_day += 1
	_planner.queue_newcomers()
	npc.position += Vector2(200.0, 0.0)
	await _planner.ask_queue()
	assert_eq(_chat.requests.size(), 0)
	assert_false(npc.asked_plans.has(DAY), "it can be queued again")
	npc.position -= Vector2(200.0, 0.0)
	await _look_next_minute()
	assert_eq(_chat.requests.size(), 1)


func test_the_evening_is_asked_before_the_day_whoever_is_nearer() -> void:
	var entries: Array[DayEntry] = [DayEntry.new("sleep", 21 * 60)]
	var for_the_day := _resident_at("hinrich", 2.0)
	for_the_day.day_plans[DAY + 1] = DayPlan.new(DAY + 1, entries, true, 0)
	var for_the_night := _resident_at("antje", 40.0)
	for_the_night.day_plans[DAY] = DayPlan.new(DAY, entries, true, 0)
	_set_time(DAY, 18)
	_planner.queue_newcomers()
	_planner.queue_evening()
	await _planner.ask_queue()
	assert_eq(_asked_names(), [for_the_night.name, for_the_day.name] as Array[String])
	assert_string_contains(_chat.requests[0]["messages"][1]["content"], "Plan the whole day")
	assert_string_contains(_chat.requests[1]["messages"][1]["content"], "It is 18:00 now")


func test_a_plan_that_comes_late_takes_over_from_its_minute() -> void:
	var npc := _resident("hinrich")
	_chat.answers = ['{"day": [{"activity": "rest", "at": "14:30"}]}']
	_set_time(DAY, 14)
	_pass_minutes(1)
	assert_eq(npc.current_step.activity, "work", "the default day while the model is asked")
	_planner.queue_newcomers()
	await _planner.ask_queue()
	assert_eq(_upkeep.entry_on(npc).activity, "work")
	_pass_minutes(31)
	assert_eq(npc.current_step.activity, "rest", "from 14:30 on, as the plan has it")


func test_nothing_is_asked_without_a_model_or_for_a_day_that_has_no_time_left() -> void:
	var npc := _resident("hinrich")
	_settings.profiles.active["endpoint"] = ""
	await _look_next_minute()
	_settings.profiles.active["endpoint"] = "http://fake/v1"
	_set_time(DAY, 23, 40)
	await _look_next_minute()
	assert_eq(_chat.requests.size(), 0)
	assert_false(npc.asked_plans.has(DAY))
