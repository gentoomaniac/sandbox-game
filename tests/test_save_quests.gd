extends SaveValidationCase
## The quests are saved (version 52): the posted and the taken ones, those done and the days they
## ended, and a save from before the quests (version 51) has none.

const QUEST := "fibre_for_beans"


func _state_with_quests() -> GameState:
	var state := GameFactory.new_game(7)
	for id in ["antje", "gesche"]:
		state.npcs.add(Npc.create_villager(id, Vector2.ZERO, state.npcs.villagers))
	state.clock.day = 12
	state.quests.post(QUEST, "antje")
	state.quests.take(state.quests.entry_of(QUEST))
	state.quests.post("stool_for_the_loom", "gesche")
	return state


func test_the_open_and_the_done_quests_come_back_after_a_save_and_a_load() -> void:
	var state := _state_with_quests()
	state.quests.post("turnips_for_the_pot", "antje")
	state.quests.finish("turnips_for_the_pot")
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_eq(restored.quests.to_dict(), state.quests.to_dict())
	assert_eq(restored.quests.open_entries().size(), 2)
	assert_true(restored.quests.entry_of_giver("antje")["is_taken"])
	assert_false(restored.quests.entry_of_giver("gesche")["is_taken"])
	assert_eq(restored.quests.entry_of(QUEST)["posted_day"], 12)
	assert_true(restored.quests.is_done("turnips_for_the_pot"))


func test_a_reload_gives_the_same_posting_of_the_next_day() -> void:
	var state := _state_with_quests()
	assert_true(SaveFile.write(state, SAVE_PATH))
	var restored := SaveFile.read(SAVE_PATH)
	for villager in ["antje", "gesche"]:
		assert_not_null(restored.npcs.find(villager))

	state.clock.advance(GameClock.MINUTES_PER_DAY)
	restored.clock.advance(GameClock.MINUTES_PER_DAY)

	assert_eq(restored.quests.open_entries(), state.quests.open_entries())


func test_a_version_51_save_has_no_quests() -> void:
	var game := _current_game()
	game.erase("quests")
	_write_save(51, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_true(restored.quests.open_entries().is_empty())
	assert_false(restored.quests.is_done(QUEST))


func test_a_quest_the_game_no_longer_has_is_left_out() -> void:
	var game := _current_game()
	game["quests"] = {
		"open":
		[
			{"id": "ghost", "giver": "antje", "posted_day": 3, "is_taken": true},
			{"id": QUEST, "giver": "antje", "posted_day": 3.0, "is_taken": false},
		],
		"done": {"ghost": 2, QUEST: 5.0},
		"ended": {"ghost": 4},
	}
	_write_save(SaveFile.VERSION, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_eq(restored.quests.open_entries().size(), 1)
	assert_eq(restored.quests.open_entries()[0]["posted_day"], 3)
	assert_eq(restored.quests.to_dict()["done"], {QUEST: 5})
	assert_true(restored.quests.to_dict()["ended"].is_empty())


func test_a_damaged_open_quest_is_refused() -> void:
	var game := _current_game()
	game["quests"] = {
		"open": [{"id": QUEST, "giver": 3, "is_taken": "yes"}, 7], "done": {}, "ended": {}
	}

	var reason: String = _refusal_of(game).reason

	assert_string_contains(reason, "quests open 0: no posted_day")
	assert_string_contains(reason, "quests open 0 giver: should be text")
	assert_string_contains(reason, "quests open 0 is_taken: should be true or false")
	assert_string_contains(reason, "quests open 1: should be a dictionary")


func test_damaged_days_of_done_quests_are_refused() -> void:
	var game := _current_game()
	game["quests"] = {"open": [], "done": {QUEST: "never"}, "ended": []}

	var reason: String = _refusal_of(game).reason

	assert_string_contains(reason, "quests done: fibre_for_beans never is not a day")
	assert_string_contains(reason, "quests ended: should be a dictionary")
