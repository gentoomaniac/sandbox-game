extends SaveValidationCase
## What a villager thinks of the player is saved, with the day's count that caps it; a save from
## before it (version 36) starts every villager at none.


func _saved_villager() -> Dictionary:
	return JSON.parse_string(
		JSON.stringify(Npc.create(42, Vector2.ZERO, NpcRules.default_rules()).to_dict())
	)


func test_the_opinion_and_what_moved_it_today_are_kept() -> void:
	var state := GameState.new_game(7)
	var antje := Npc.create_villager("antje", Vector2(3.5, 4.5), state.npcs.villagers)
	antje.change_opinion(15, 4, GossipRules.default_rules())
	state.npcs.add(antje)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq([loaded.opinion, loaded.opinion_day, loaded.opinion_moved_today], [15, 4, 15])


func test_a_version_36_save_loads_every_villager_with_no_opinion() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	for key in ["opinion", "opinion_day", "opinion_moved_today"]:
		saved.erase(key)
	game["npcs"] = [saved]
	_write_save(36, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq([loaded.opinion, loaded.opinion_day, loaded.opinion_moved_today], [0, 0, 0])


func test_an_opinion_that_is_not_a_whole_number_is_refused() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	saved["opinion"] = "warm"
	saved.erase("opinion_day")
	game["npcs"] = [saved]

	var problems: Array = _refusal_of(game).problems

	assert_eq(problems.size(), 2, str(problems))
	assert_true(problems.has("npcs 0: no opinion_day"), str(problems))
