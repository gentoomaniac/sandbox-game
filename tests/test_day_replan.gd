extends DayPlannerCase
## The console's `replan` (DayPlanner `replan`): the rest of today planned at once, ahead of the
## evening's queue. The model is a fake (FakeChat).

# --- The console's replan ---


func test_replan_asks_for_the_rest_of_today_and_the_plan_takes_over_from_its_minute() -> void:
	var npc := _resident("hinrich")
	_chat.answers = [REST_OF_DAY_ANSWER]
	_set_time(DAY, 13, 10)
	_pass_minutes(1)
	assert_eq(npc.current_step.activity, "work", "the default day, as the model was not asked")

	assert_eq(_planner.replan(npc), "Asking the model for the rest of the day of Hinrich Boysen")
	await _planner.ask_queue()

	assert_string_contains(_chat.requests[0]["messages"][1]["content"], "It is 13:11 now")
	var plan: DayPlan = npc.day_plans[DAY]
	assert_false(plan.is_whole_day)
	assert_eq(_upkeep.entry_on(npc).activity, "work", "13:30 is not here yet")
	_pass_minutes(25)
	assert_eq(npc.current_step.activity, "rest")
	assert_eq(_upkeep.entry_on(npc).why, "feet up")


func test_replan_goes_ahead_of_the_evening_queue() -> void:
	var nearer := _resident_at("hinrich", 2.0)
	var farther := _resident_at("antje", 20.0)
	_set_time(DAY, 18)
	_planner.queue_evening()
	_planner.replan(farther)
	await _planner.ask_queue()
	assert_eq(_asked_names(), [farther.name, nearer.name] as Array[String])


func test_replan_without_a_model_or_a_house_says_so() -> void:
	var npc := _resident("hinrich")
	_settings.profiles.active["endpoint"] = ""
	assert_eq(_planner.replan(npc), "No model set: default day")
	_settings.profiles.active["endpoint"] = "http://fake/v1"
	npc.house = null
	assert_eq(_planner.replan(npc), "Hinrich Boysen has no house: default day")
	await _planner.ask_queue()
	assert_eq(_chat.requests.size(), 0)


func test_replan_asks_anyway_with_day_plans_switched_off_and_says_so() -> void:
	var npc := _resident("hinrich")
	_settings.profiles.set_uses_model_for(&"day_plans", false)
	assert_eq(
		_planner.replan(npc),
		(
			"Asking the model for the rest of the day of Hinrich Boysen"
			+ " (day plans are switched off in the profile: asked anyway, as a test)"
		)
	)
	await _planner.ask_queue()
	assert_eq(_chat.requests.size(), 1)


func test_replan_asks_again_after_a_failure() -> void:
	var npc := _resident("hinrich")
	_chat.answers = ["no idea", REST_OF_DAY_ANSWER]
	_set_time(DAY, 13)
	_planner.replan(npc)
	await _planner.ask_queue()
	assert_eq(npc.asked_plans[DAY], DayPlan.FAILED)
	_planner.replan(npc)
	await _planner.ask_queue()
	assert_true(npc.day_plans.has(DAY))


func test_a_plan_whose_day_is_over_when_it_comes_is_dropped() -> void:
	var npc := _resident("hinrich")
	_chat.seconds = 0.05
	_set_time(DAY, 13)
	_planner.replan(npc)
	_planner.ask_queue()
	_set_time(DAY + 1, 1)
	await get_tree().create_timer(0.15).timeout
	assert_false(npc.day_plans.has(DAY))
