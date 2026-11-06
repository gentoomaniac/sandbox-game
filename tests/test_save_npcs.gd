extends SaveUpgradeCase
## The villagers are saved with their name, sex, look, place, anchor and chat, and a save from
## before them (version 16) loads without any.


func test_the_villagers_and_their_chat_are_kept() -> void:
	var state := GameState.new_game(7)
	var npc := Npc.create(42, Vector2(3.25, -4.5), state.npcs.rules)
	npc.anchor = Vector2(1.5, -2.5)
	npc.add_chat_line(3, 495, true, "hello")
	npc.add_chat_line(3, 495, false, "I understand.")
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


func test_a_saved_chat_keeps_its_last_lines_only() -> void:
	var state := GameState.new_game(7)
	var npc := Npc.create(42, Vector2.ZERO, state.npcs.rules)
	for index in Npc.HISTORY_LIMIT + 10:
		npc.add_chat_line(1, 600, true, "line %d" % index)
	state.npcs.add(npc)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var history := SaveFile.read(SAVE_PATH).npcs.all()[0].chat_history

	assert_eq(history.size(), Npc.HISTORY_LIMIT)
	assert_eq(history[0]["text"], "line 10")


func test_a_version_16_save_loads_with_no_villagers() -> void:
	var game := _current_game()
	game.erase("npcs")
	_write_save(16, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_eq(restored.npcs.all().size(), 0)
