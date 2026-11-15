extends QuestsCase
## The quests the villagers post (Quests, data/quests/): which is posted on a day and who gives it,
## the limits, and how a quest goes away.


func test_a_new_game_with_a_village_posts_a_starter_of_a_random_villager() -> void:
	var state := GameState.new_game(1, true)

	var entries := state.quests.open_entries()

	assert_eq(entries.size(), 1)
	assert_true(state.quests.rules.is_starter(entries[0]["id"]))
	assert_not_null(state.npcs.find(entries[0]["giver"]))
	assert_eq(entries[0]["posted_day"], 1)
	assert_false(entries[0]["is_taken"])


func test_a_new_game_with_no_villagers_posts_nothing() -> void:
	var state := GameState.new_game(7)

	assert_true(state.quests.open_entries().is_empty())
	assert_eq(state.quests.post_first(), "")


func test_the_first_quest_is_a_starter_and_a_later_one_may_be_any() -> void:
	_use_rules({"starter_one": {"starter": true}, "later": {"starter": false, "requires": []}})

	assert_eq(_quests.post_first(), "starter_one")
	assert_eq(_quests.post_today(), "", "today's is posted")
	_pass_days(1)

	assert_eq(_ids_open(), ["starter_one", "later"] as Array[String])


func test_one_quest_is_posted_a_day_and_stays_its_days() -> void:
	_use_rules({"a": {}, "b": {}, "c": {}}, {"per_day": 1})

	_pass_days(1)
	assert_eq(_quests.open_entries().size(), 1)
	assert_eq(_quests.open_entries()[0]["posted_day"], 2)
	_pass_days(1)
	assert_eq(_quests.open_entries().size(), 2, "two givers, so two quests")
	_pass_days(1)
	assert_eq(_quests.open_entries().size(), 2, "no giver is left")


func test_at_most_max_open_are_open_at_once() -> void:
	_use_rules({"a": {"giver": ANTJE}, "b": {"giver": GESCHE}}, {"max_open": 1})

	_pass_days(3)

	assert_eq(_quests.open_entries().size(), 1)


func test_a_giver_has_one_quest_at_a_time() -> void:
	_use_rules({"a": {"giver": ANTJE}, "b": {"giver": ANTJE}})

	_pass_days(3)

	assert_eq(_quests.open_entries().size(), 1)


func test_a_giver_picked_at_random_is_one_who_is_in_the_world() -> void:
	_use_rules({"a": {"giver": "any"}})

	_pass_days(1)

	assert_has([ANTJE, GESCHE], _quests.open_entries()[0]["giver"])


func test_a_cold_villager_gives_no_quest() -> void:
	_use_rules({"a": {"giver": ANTJE}})
	_state.npcs.find(ANTJE).opinion = GossipRules.default_rules().opinion_cold_below() - 1

	_pass_days(2)

	assert_true(_quests.open_entries().is_empty())


func test_a_quest_of_a_villager_who_is_not_in_the_world_is_not_posted() -> void:
	_use_rules({"a": {"giver": "trienke"}})

	_pass_days(2)

	assert_true(_quests.open_entries().is_empty())


func test_the_same_day_and_world_give_the_same_pick() -> void:
	_use_rules({"a": {}, "b": {}, "c": {}, "d": {}})
	_quests.post_today()
	var first := _quests.open_entries()[0].duplicate()
	var other := GameState.new_game(7)
	other.npcs.add(Npc.create_villager(ANTJE, Vector2.ZERO, other.npcs.villagers))
	other.npcs.add(Npc.create_villager(GESCHE, Vector2.ZERO, other.npcs.villagers))
	other.quests.rules = _quests.rules

	other.quests.post_today()

	assert_eq(other.quests.open_entries()[0], first)


func test_a_quest_goes_away_the_morning_after_its_last_day_without_a_word_of_blame() -> void:
	_use_rules({"a": {"giver": ANTJE, "days": 3}})
	var notices: Array[String] = []
	_quests.noticed.connect(func(text: String) -> void: notices.append(text))
	_pass_days(1)
	assert_eq(_quests.open_entries()[0]["posted_day"], 2)
	assert_eq(_quests.rules.last_day_of(_quests.open_entries()[0]), 4)

	_pass_days(2)
	assert_eq(_ids_open(), ["a"] as Array[String], "day 4, the last day")
	_pass_days(1)

	assert_true(_quests.open_entries().is_empty())
	assert_eq(notices.back(), "Antje Boysen no longer needs the fibre.")
	assert_eq(_state.npcs.find(ANTJE).opinion, 0)
	assert_false(_quests.is_done("a"))


func test_a_quest_is_posted_again_only_after_the_days_of_repeat() -> void:
	_use_rules({"a": {"giver": ANTJE, "days": 1}}, {"repeat_after_days": 5})
	_pass_days(1)
	assert_eq(_ids_open(), ["a"] as Array[String], "day 2")
	_pass_days(1)
	assert_true(_quests.open_entries().is_empty(), "went away on day 3")

	_pass_days(4)
	assert_true(_quests.open_entries().is_empty(), "day 7: 4 days since")
	_pass_days(1)

	assert_eq(_ids_open(), ["a"] as Array[String], "day 8: 5 days since")


func test_a_skip_of_many_days_lets_every_quest_expire() -> void:
	_use_rules({"a": {"giver": ANTJE, "days": 2}, "b": {"giver": GESCHE, "days": 2}})
	_pass_days(2)
	assert_eq(_quests.open_entries().size(), 2)

	_state.simulation.skip(20 * GameClock.MINUTES_PER_DAY)

	assert_false(_quests.is_open("a") and _quests.is_open("b"))
	for entry in _quests.open_entries():
		assert_lte(_state.clock.day - entry["posted_day"], 1)


func test_post_puts_a_quest_up_whatever_it_needs_and_names_what_is_wrong() -> void:
	_use_rules({"a": {"requires": [{"type": "day", "at_least": 99}]}})

	assert_eq(_quests.post("a", GESCHE), "")
	assert_eq(_quests.open_entries()[0]["giver"], GESCHE)
	assert_eq(_quests.post("a"), "a is open already")
	assert_eq(_quests.post("zzz"), "No quest zzz")
	_quests.clear()
	assert_eq(_quests.post("a", "trienke"), "No villager trienke in the world")


func test_finish_and_clear() -> void:
	_use_rules({"a": {}})
	_quests.post("a", ANTJE)

	assert_false(_quests.finish("zzz"))
	assert_true(_quests.finish("a"))
	assert_true(_quests.is_done("a"))
	assert_false(_quests.is_open("a"))
	_quests.clear()
	assert_false(_quests.is_done("a"))


func test_a_posted_quest_is_told_with_the_name_of_its_giver() -> void:
	_use_rules({"a": {"giver": GESCHE}})
	var notices: Array[String] = []
	_quests.noticed.connect(func(text: String) -> void: notices.append(text))

	_quests.post("a", GESCHE)

	assert_eq(notices, ["Gesche Hansen has something for you."] as Array[String])


func test_up_to_per_day_quests_are_posted_in_a_day() -> void:
	_use_rules({"a": {}, "b": {}, "c": {}}, {"per_day": 2})

	_pass_days(1)

	assert_eq(_quests.open_entries().size(), 2, "two givers, two a day")
	_pass_days(1)
	assert_eq(_quests.open_entries().size(), 2, "no giver is left for a third")
