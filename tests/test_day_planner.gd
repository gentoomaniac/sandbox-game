extends DayPlannerCase
## The queue that has the language model plan the days of the villagers nearest the player
## (DayPlanner) in the evening, for tomorrow. The model is a fake (FakeChat).

# --- The evening ---


func test_nothing_is_asked_before_the_planning_hour() -> void:
	_resident("hinrich")
	_set_time(DAY, 17, 59)
	_planner.queue_evening()
	await _planner.ask_queue()
	assert_eq(_chat.requests.size(), 0)


func test_at_the_planning_hour_the_villager_is_asked_for_tomorrow_quietly_within_the_timeout(
) -> void:
	var npc := _resident("hinrich")
	await _plan_evening()
	assert_eq(_chat.requests.size(), 1)
	assert_eq(_chat.quiet_flags, [true] as Array[bool])
	assert_eq(_chat.timeouts, [20.0] as Array[float])
	assert_string_contains(_chat.requests[0]["messages"][1]["content"], npc.name)
	assert_string_contains(_chat.requests[0]["messages"][1]["content"], "Plan the whole day")
	assert_string_contains(_chat.requests[0]["messages"][1]["content"], "Friday")


func test_a_usable_answer_becomes_tomorrows_plan() -> void:
	var npc := _resident("hinrich")
	await _plan_evening()
	var plan: DayPlan = npc.day_plans[DAY + 1]
	assert_true(plan.is_whole_day)
	assert_eq(plan.made_at, _state.clock.total_minutes())
	assert_eq(plan.entries[0].activity, "breakfast")
	assert_eq(plan.entries[0].why, "a late start")
	assert_false(npc.day_plans.has(DAY), "today is not touched")
	assert_false(npc.asked_plans.has(DAY + 1), "it is no longer waiting")
	assert_eq(_upkeep.entries_of(npc, DAY + 1)[0].why, "a late start")


func test_an_answer_that_cannot_be_used_leaves_the_default_day_and_is_not_asked_again() -> void:
	var npc := _resident("hinrich")
	_chat.answers = ["The day will be fine."]
	await _plan_evening()
	assert_false(npc.day_plans.has(DAY + 1))
	assert_eq(npc.asked_plans[DAY + 1], DayPlan.FAILED)
	_planner.queue_evening()
	await _planner.ask_queue()
	assert_eq(_chat.requests.size(), 1)
	_set_time(DAY + 1, 18)
	_planner.queue_evening()
	await _planner.ask_queue()
	assert_eq(_chat.requests.size(), 2, "the next evening is for the next day")


func test_no_answer_in_time_is_no_plan_and_the_next_villager_is_asked() -> void:
	var first := _resident_at("hinrich", 0.0)
	var second := _resident_at("antje", 5.0)
	_chat.answers = ["", EVENING_ANSWER]
	await _plan_evening()
	assert_eq(_chat.requests.size(), 2)
	assert_eq(first.asked_plans[DAY + 1], DayPlan.FAILED)
	assert_true(second.day_plans.has(DAY + 1))


func test_the_nearest_villagers_are_asked_first() -> void:
	var far := _resident_at("antje", 30.0)
	var near := _resident_at("hinrich", 5.0)
	var middle := _resident_at("momme", 12.0)
	await _plan_evening()
	assert_eq(_asked_names(), [near.name, middle.name, far.name] as Array[String])


func test_the_villagers_beyond_the_radius_are_not_asked() -> void:
	_resident_at("hinrich", 5.0)
	var far := _resident_at("antje", 121.0)
	await _plan_evening()
	assert_eq(_chat.requests.size(), 1)
	assert_false(far.asked_plans.has(DAY + 1))


func test_the_evening_asks_for_at_most_the_most_a_night() -> void:
	_with_plan_value("max_per_night", 2)
	var nearest := _resident_at("hinrich", 3.0)
	var next := _resident_at("antje", 6.0)
	var left_out := _resident_at("momme", 9.0)
	await _plan_evening()
	assert_eq(_asked_names(), [nearest.name, next.name] as Array[String])
	assert_false(left_out.asked_plans.has(DAY + 1))


func test_a_villager_with_a_plan_for_tomorrow_is_not_asked() -> void:
	var npc := _resident("hinrich")
	var entries: Array[DayEntry] = [DayEntry.new("sleep", 21 * 60)]
	npc.day_plans[DAY + 1] = DayPlan.new(DAY + 1, entries, true, 0)
	await _plan_evening()
	assert_eq(_chat.requests.size(), 0)


func test_a_villager_with_no_house_is_not_asked() -> void:
	var npc := _resident("hinrich")
	npc.house = null
	await _plan_evening()
	assert_eq(_chat.requests.size(), 0)


func test_without_a_model_nothing_is_asked() -> void:
	_resident("hinrich")
	_settings.profiles.active["endpoint"] = ""
	await _plan_evening()
	assert_eq(_chat.requests.size(), 0)


func test_the_evening_is_queued_once_a_day() -> void:
	_resident("hinrich")
	await _plan_evening()
	_set_time(DAY, 19)
	_planner.queue_evening()
	await _planner.ask_queue()
	assert_eq(_chat.requests.size(), 1)


func test_no_query_for_tomorrow_starts_after_ten_to_midnight() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 18)
	_planner.queue_evening()
	_set_time(DAY, 23, 50)
	await _planner.ask_queue()
	assert_eq(_chat.requests.size(), 0)
	assert_false(npc.asked_plans.has(DAY + 1), "dropped, so that it can be asked for again")


func test_the_queries_are_asked_one_at_a_time() -> void:
	_resident_at("hinrich", 3.0)
	_resident_at("antje", 6.0)
	_chat.seconds = 0.05
	_set_time(DAY, 18)
	_planner.queue_evening()
	_planner.ask_queue()
	_planner.ask_queue()
	await get_tree().process_frame
	assert_eq(_chat.requests.size(), 1, "the second call leaves the queue to the one at work")


func test_the_queue_waits_while_a_chat_reply_is_awaited() -> void:
	var npc := _resident("hinrich")
	npc.is_answering = true
	await _plan_evening()
	assert_eq(_chat.requests.size(), 0)
	npc.is_answering = false
	await _planner.ask_queue()
	assert_eq(_chat.requests.size(), 1)


func test_a_villager_who_is_gone_is_not_asked() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 18)
	_planner.queue_evening()
	_npcs.remove(npc)
	await _planner.ask_queue()
	assert_eq(_chat.requests.size(), 0)


# --- What the model is told ---


func test_the_request_has_the_activities_on_offer_with_their_walks_and_yesterday() -> void:
	_resident("hinrich")
	await _plan_evening()
	var text: String = _chat.requests[0]["messages"][1]["content"]
	assert_string_contains(text, "- breakfast: have breakfast, 0 minutes' walk, usually at 05:30")
	assert_string_contains(text, "- sleep: sleep, 0 minutes' walk")
	assert_string_contains(text, "Yesterday Hinrich did: 05:")
	assert_string_contains(text, "The weather that day: ")
