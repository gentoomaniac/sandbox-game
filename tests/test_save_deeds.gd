extends SaveValidationCase
## The deed log and the stories of the villagers are saved; a save from before them (version 33)
## has none.


func _state_with_a_deed_seen_by_antje() -> GameState:
	var state := GameState.new_game(7)
	var antje := Npc.create_villager("antje", Vector2(3.5, 4.5), state.npcs.villagers)
	state.npcs.add(antje)
	state.clock.day = 4
	state.clock.minute_of_day = 745
	state.report(ActionOutcome.BREAK, Vector2i(3, 4), WorldObjectTypes.OAK, {})
	state.report(ActionOutcome.BREAK, Vector2i(3, 4), WorldObjectTypes.OAK, {})
	return state


func test_the_deed_log_and_the_stories_are_kept() -> void:
	var state := _state_with_a_deed_seen_by_antje()
	assert_true(SaveFile.write(state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH)

	assert_eq(loaded.deeds.entries.size(), 1)
	var entry := loaded.deeds.entries[0]
	assert_eq(entry, state.deeds.entries[0])
	assert_eq(entry["kind"], GossipRules.FELLED)
	assert_eq(entry["count"], 2)
	assert_eq(loaded.npcs.all()[0].stories, state.npcs.all()[0].stories)


func test_a_version_33_save_loads_without_deeds() -> void:
	var game := _current_game()
	game["npcs"] = [
		JSON.parse_string(
			JSON.stringify(Npc.create(42, Vector2.ZERO, NpcRules.default_rules()).to_dict())
		)
	]
	game.erase("deeds")
	game["npcs"][0].erase("stories")
	_write_save(33, game)

	var loaded := SaveFile.read(SAVE_PATH)

	assert_eq(loaded.deeds.entries, [] as Array[Dictionary])
	assert_eq(loaded.npcs.all()[0].stories, [] as Array[Dictionary])


func test_a_version_34_save_loads_its_stories_as_seen_and_medium() -> void:
	var game := _current_game()
	var saved: Dictionary = JSON.parse_string(
		JSON.stringify(Npc.create(42, Vector2.ZERO, NpcRules.default_rules()).to_dict())
	)
	saved["stories"] = [
		{"day": 4, "minute": 600, "kind": "felled", "count": 3, "place": "out on the geest"}
	]
	game["npcs"] = [saved]
	_write_save(34, game)

	var story := SaveFile.read(SAVE_PATH).npcs.all()[0].stories[0]

	assert_eq(story["how"], GossipRules.SEEN)
	assert_eq(story["seen_by"], saved["name"])
	assert_eq([story["hops"], story["learned"], story["personal"]], [0, 4, false])
	assert_eq(story["weight"], MemoryWeight.MEDIUM)


func test_a_deed_of_an_unknown_kind_or_without_a_place_is_refused() -> void:
	var state := _state_with_a_deed_seen_by_antje()
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	game["deeds"][0]["kind"] = "stole"
	game["npcs"][0]["stories"][0].erase("place")
	game["npcs"][0]["stories"][0]["weight"] = "huge"

	var problems: Array = _refusal_of(game).problems

	assert_true(problems.has("deeds 0: unknown deed stole"), str(problems))
	assert_true(problems.has("npcs 0 stories 0: no place"), str(problems))
	assert_true(problems.has("npcs 0 stories 0: unknown weight huge"), str(problems))
