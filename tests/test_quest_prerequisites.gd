extends QuestsCase
## The prerequisites of a quest (data/quests/, the kinds in game/state/quests/conditions): each
## holds and fails.


func test_the_opinion_prerequisite_holds_from_its_points_for_the_giver() -> void:
	_use_rules({"a": {"giver": ANTJE, "requires": [{"type": "opinion", "at_least": 10}]}})
	_pass_days(1)
	assert_true(_quests.open_entries().is_empty())

	_state.npcs.find(ANTJE).opinion = 10
	_pass_days(1)

	assert_eq(_ids_open(), ["a"] as Array[String])


func test_the_opinion_prerequisite_may_name_another_villager() -> void:
	var needs := {"type": "opinion", "at_least": 10, "villager": GESCHE}
	_use_rules({"a": {"giver": ANTJE, "requires": [needs]}})
	_state.npcs.find(ANTJE).opinion = 50
	_pass_days(1)
	assert_true(_quests.open_entries().is_empty())

	_state.npcs.find(GESCHE).opinion = 10
	_pass_days(1)

	assert_eq(_ids_open(), ["a"] as Array[String])


func test_the_skill_prerequisite_holds_from_its_points() -> void:
	_use_rules({"a": {"requires": [{"type": "skill", "skill": "woodworking", "at_least": 5}]}})
	_state.player.skills.set_points(&"woodworking", 4.9)
	_pass_days(1)
	assert_true(_quests.open_entries().is_empty())

	_state.player.skills.set_points(&"woodworking", 5.0)
	_pass_days(1)

	assert_eq(_ids_open(), ["a"] as Array[String])


func test_the_season_prerequisite_holds_in_its_seasons() -> void:
	_use_rules({"a": {"requires": [{"type": "season", "seasons": ["summer"]}]}})
	_pass_days(GameClock.DAYS_PER_SEASON - 2)
	assert_true(_quests.open_entries().is_empty(), "spring still")

	_pass_days(2)

	assert_eq(_ids_open(), ["a"] as Array[String])


func test_the_day_prerequisite_holds_between_its_days() -> void:
	_use_rules({"a": {"requires": [{"type": "day", "at_least": 3, "at_most": 3}]}})

	_pass_days(1)
	assert_true(_quests.open_entries().is_empty(), "day 2")
	_pass_days(1)

	assert_eq(_ids_open(), ["a"] as Array[String], "day 3")


func test_the_quest_done_prerequisite_holds_once_that_quest_is_done() -> void:
	_use_rules(
		{
			"first": {"giver": ANTJE},
			"second": {"requires": [{"type": "quest_done", "quest": "first"}]}
		}
	)
	_pass_days(1)
	assert_eq(_ids_open(), ["first"] as Array[String])

	assert_true(_quests.finish("first"))
	_pass_days(1)

	assert_true(_quests.is_done("first"))
	assert_eq(_ids_open(), ["second"] as Array[String])
