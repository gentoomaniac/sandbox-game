extends SaveUpgradeCase
## The villagers are saved with their name, sex, look, who they are, place, anchor and chat; a
## save from before them (version 16) loads without any, one from before their backgrounds
## (version 18) gives them one, and one from before their memories (version 19) none.


func test_the_villagers_and_their_chat_are_kept() -> void:
	var state := GameState.new_game(7)
	var npc := Npc.create(42, Vector2(3.25, -4.5), state.npcs.rules)
	npc.anchor = Vector2(1.5, -2.5)
	npc.add_chat_line(3, 495, true, "hello")
	npc.add_chat_line(3, 495, false, "I understand.")
	npc.add_memory("On the 3rd day of Spring, year 1 (early spring): The neighbour said hello.")
	state.npcs.add(npc)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var villagers := SaveFile.read(SAVE_PATH).npcs.all()

	assert_eq(villagers.size(), 1)
	var loaded := villagers[0]
	assert_eq(loaded.name, npc.name)
	assert_eq(loaded.sex, npc.sex)
	assert_eq(loaded.appearance.to_dict(), npc.appearance.to_dict())
	assert_eq(loaded.position, Vector2(3.25, -4.5))
	assert_eq(loaded.anchor, Vector2(1.5, -2.5))
	assert_eq(loaded.chat_history, npc.chat_history)
	assert_eq(loaded.chat_history[0]["minute"], 495)
	assert_eq(loaded.age, npc.age)
	assert_eq(loaded.trade, npc.trade)
	assert_eq(loaded.personality, npc.personality)
	assert_eq(loaded.background, npc.background)
	assert_eq(loaded.habits, npc.habits)
	assert_eq(loaded.memories, npc.memories)
	assert_eq(loaded.uncompacted_lines, npc.uncompacted_lines)


func test_a_villager_written_by_hand_keeps_their_id() -> void:
	var state := GameState.new_game(7)
	state.npcs.add(Npc.create_villager("antje", Vector2.ZERO, state.npcs.villagers))
	assert_true(SaveFile.write(state, SAVE_PATH))

	var antje := SaveFile.read(SAVE_PATH).npcs.find("antje")

	assert_not_null(antje)
	assert_eq(antje.trade, "a farmer's wife")


func test_the_lines_waiting_for_a_memory_are_saved() -> void:
	var state := GameState.new_game(7)
	var npc := Npc.create(42, Vector2.ZERO, state.npcs.rules)
	for index in 5:
		npc.add_chat_line(1, 600, true, "line %d" % index)
	npc.drop_old_lines(3)
	state.npcs.add(npc)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq(loaded.chat_history.size(), 3)
	assert_eq(
		loaded.uncompacted_lines.map(func(line: Dictionary) -> String: return line["text"]),
		["line 0", "line 1"]
	)


func test_a_version_16_save_loads_with_no_villagers() -> void:
	var game := _current_game()
	game.erase("npcs")
	_write_save(16, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_eq(restored.npcs.all().size(), 0)


func test_a_version_18_villager_is_given_a_background_from_the_tables() -> void:
	var game := _current_game()
	var npc := Npc.create(42, Vector2.ZERO, NpcRules.default_rules()).to_dict()
	for key in ["id", "age", "trade", "personality", "background", "habits"]:
		npc.erase(key)
	game["npcs"] = [JSON.parse_string(JSON.stringify(npc))]
	_write_save(18, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq(loaded.id, "")
	assert_between(loaded.age, 18, 70)
	assert_false(loaded.trade.is_empty())
	assert_false(loaded.background.is_empty())


func test_a_version_19_villager_remembers_nothing() -> void:
	var game := _current_game()
	var npc := Npc.create(42, Vector2.ZERO, NpcRules.default_rules()).to_dict()
	npc.erase("memories")
	npc.erase("uncompacted_lines")
	npc.erase("remembered_lines")
	npc["lines_since_memory"] = 0
	game["npcs"] = [JSON.parse_string(JSON.stringify(npc))]
	_write_save(19, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq(loaded.memories.size(), 0)
	assert_eq(loaded.uncompacted_lines.size(), 0)


func test_a_version_20_villager_keeps_their_chat_and_the_lines_a_memory_holds_are_marked() -> void:
	var game := _current_game()
	var npc := Npc.create(42, Vector2.ZERO, NpcRules.default_rules())
	for text in ["old", "older", "Moin"]:
		npc.add_chat_line(1, 600, true, text)
	var saved := npc.to_dict()
	saved.erase("uncompacted_lines")
	saved.erase("remembered_lines")
	saved["lines_since_memory"] = 1
	game["npcs"] = [JSON.parse_string(JSON.stringify(saved))]
	_write_save(20, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq(loaded.chat_history.size(), 3)
	assert_eq(loaded.remembered_lines, 2, "only the last line is not in a memory")
	assert_eq(loaded.uncompacted_lines.size(), 0)
