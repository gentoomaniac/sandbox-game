extends QuestsCase
## What the player's list of quests shows (QuestRows): the taken quests, the oldest first, with
## who and what, how far, the days left and the reward.


func _take(id: String, giver: String) -> void:
	_quests.post(id, giver)
	QuestTalk.greet_and_say(_state, _state.npcs.find(giver))


func before_each() -> void:
	super.before_each()
	_state.player.inventory = Inventory.new()


func test_a_game_with_no_quest_taken_has_no_rows() -> void:
	assert_true(QuestRows.of(_state).is_empty())


func test_a_quest_that_is_only_posted_is_not_in_the_list() -> void:
	_use_rules({"a": {}})
	_quests.post("a", ANTJE)

	assert_true(QuestRows.of(_state).is_empty())


func test_a_taken_bring_quest_shows_who_what_how_far_the_days_left_and_the_reward() -> void:
	_use_rules({"a": {}})
	_take("a", ANTJE)
	_state.player.inventory.add(ItemTypes.FIBRE, 3)

	var rows := QuestRows.of(_state)

	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["giver"], "Antje Boysen, a farmer's wife")
	assert_eq(rows[0]["what"], "5 fibre")
	assert_eq(rows[0]["progress"], "you carry 3")
	assert_eq(rows[0]["days_left"], "8 days left")
	assert_eq(rows[0]["reward"], "Reward: 10 turnip seeds and goodwill in the village")


func test_the_days_left_count_down_to_the_last_day() -> void:
	_use_rules({"a": {"days": 3}})
	_take("a", ANTJE)

	_state.clock.day += 1
	assert_eq(QuestRows.of(_state)[0]["days_left"], "2 days left")
	_state.clock.day += 1
	assert_eq(QuestRows.of(_state)[0]["days_left"], "last day")


func test_a_quest_with_no_opinion_reward_names_only_the_items() -> void:
	_use_rules({"a": {"reward": {"items": {"wax": 2}}}})
	_take("a", ANTJE)

	assert_eq(QuestRows.of(_state)[0]["reward"], "Reward: 2 wax")


func test_a_build_quest_shows_the_pieces_up_of_the_goal() -> void:
	var objective := {
		"type": "build", "object": "wattle_fence", "count": 6, "near": "home", "radius": 8
	}
	_use_rules({"a": {"objective": objective}})
	_take("a", GESCHE)

	var row := QuestRows.of(_state)[0]

	assert_eq(row["what"], "put up 6 wattle fence by the home")
	assert_eq(row["progress"], "0 of 6")


func test_the_oldest_quest_comes_first() -> void:
	_use_rules({"a": {}, "b": {"objective": {"type": "bring", "item": "logs", "count": 2}}})
	_take("b", GESCHE)
	_take("a", ANTJE)

	var rows := QuestRows.of(_state)

	assert_eq(rows.map(func(row: Dictionary) -> String: return row["what"]), ["2 logs", "5 fibre"])
