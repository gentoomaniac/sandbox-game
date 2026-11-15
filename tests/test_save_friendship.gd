extends SaveValidationCase
## What a villager has of the player's friendship besides the opinion is saved (version 53): the
## day of the last gift, of the chat that counted, the day's count of the actions and of the word
## ratings, and the bond. An older save has the defaults.


func _saved_villager() -> Dictionary:
	return JSON.parse_string(
		JSON.stringify(Npc.create(42, Vector2.ZERO, NpcRules.default_rules()).to_dict())
	)


func _problems_with(key: String, value: Variant) -> Array:
	var saved := _saved_villager()
	saved[key] = value
	var game := _current_game()
	game["npcs"] = [saved]
	return _refusal_of(game).problems


func test_the_friendship_of_a_villager_is_kept() -> void:
	var state := GameState.new_game(7)
	var antje := Npc.create_villager("antje", Vector2(3.5, 4.5), state.npcs.villagers)
	antje.change_friendship(30, 4, FriendshipRules.default_rules(), GossipRules.default_rules())
	antje.last_gift_day = 4
	antje.chat_counted_day = 3
	antje.rating_day = 4
	antje.ratings_today = 2
	antje.rating_moved_today = -10
	state.npcs.add(antje)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq([loaded.action_day, loaded.action_moved_today], [4, 30])
	assert_eq([loaded.last_gift_day, loaded.chat_counted_day], [4, 3])
	assert_eq([loaded.rating_day, loaded.ratings_today, loaded.rating_moved_today], [4, 2, -10])
	assert_eq(loaded.bond, FriendshipRules.BOND_NONE)


func test_a_version_52_save_keeps_the_opinion_and_has_the_defaults() -> void:
	var state := GameState.new_game(7)
	var antje := Npc.create_villager("antje", Vector2(3.5, 4.5), state.npcs.villagers)
	antje.opinion = 150
	state.npcs.add(antje)
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	for npc: Dictionary in game["npcs"]:
		for key in [
			"action_day",
			"action_moved_today",
			"last_gift_day",
			"chat_counted_day",
			"rating_day",
			"ratings_today",
			"rating_moved_today",
			"bond"
		]:
			npc.erase(key)
	_write_save(52, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq(loaded.opinion, 150)
	assert_eq(FriendshipRules.default_rules().level_of(loaded.opinion), 5)
	assert_eq([loaded.action_day, loaded.action_moved_today, loaded.last_gift_day], [0, 0, 0])
	assert_eq([loaded.chat_counted_day, loaded.rating_day, loaded.ratings_today], [0, 0, 0])
	assert_eq(loaded.bond, FriendshipRules.BOND_NONE)


func test_a_negative_day_or_count_is_refused() -> void:
	assert_eq(_problems_with("last_gift_day", -1), ["npcs 0 last_gift_day: should not be negative"])
	assert_eq(_problems_with("ratings_today", -2), ["npcs 0 ratings_today: should not be negative"])


func test_what_actions_moved_beyond_the_cap_is_refused() -> void:
	var cap := FriendshipRules.default_rules().action_daily_cap()
	assert_eq(_problems_with("action_moved_today", -cap - 1).size(), 1)


func test_an_unknown_bond_is_refused() -> void:
	assert_eq(_problems_with("bond", "married"), ["npcs 0 bond: unknown bond married"])
