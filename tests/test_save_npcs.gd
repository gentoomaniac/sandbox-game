extends SaveUpgradeCase
## The villagers are saved with their name, sex, look, who they are, place, anchor and chat; a
## save from before them (version 16) loads without any, one from before their backgrounds
## (version 18) gives them one, one from before their memories (version 19) none, and one from
## before their long sheets (version 22) gives them those.


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
	assert_eq(
		[loaded.home, loaded.speech, loaded.samples, loaded.likes, loaded.wants, loaded.day],
		[npc.home, npc.speech, npc.samples, npc.likes, npc.wants, npc.day]
	)
	assert_eq([loaded.avoids, loaded.secrets], [npc.avoids, npc.secrets])
	assert_eq(loaded.memories, npc.memories)
	assert_eq(loaded.uncompacted_lines, npc.uncompacted_lines)


func test_a_villager_written_by_hand_keeps_their_id() -> void:
	var state := GameState.new_game(7)
	state.npcs.add(Npc.create_villager("antje", Vector2.ZERO, state.npcs.villagers))
	assert_true(SaveFile.write(state, SAVE_PATH))

	var antje := SaveFile.read(SAVE_PATH).npcs.find("antje")

	assert_not_null(antje)
	assert_eq(antje.trade, "a farmer's wife")
	assert_eq(antje.people["hinrich"][0], "husband")


func test_a_villager_written_by_hand_is_as_the_data_file_has_them_now() -> void:
	var game := _current_game()
	var saved: Dictionary = JSON.parse_string(
		JSON.stringify(
			Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules()).to_dict()
		)
	)
	saved["background"] = "Words the file no longer has."
	game["npcs"] = [saved]
	_write_save(SaveFile.VERSION, game)

	var antje := SaveFile.read(SAVE_PATH).npcs.find("antje")

	assert_eq(antje.background, VillagerRules.default_rules().villager("antje")["background"])


func test_a_villager_whose_id_left_the_data_file_keeps_their_saved_sheet() -> void:
	var game := _current_game()
	var saved: Dictionary = JSON.parse_string(
		JSON.stringify(
			Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules()).to_dict()
		)
	)
	saved["id"] = "antje_of_an_older_file"
	saved["background"] = "Words only the save has."
	game["npcs"] = [saved]
	_write_save(SaveFile.VERSION, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq(loaded.id, "antje_of_an_older_file")
	assert_eq(loaded.background, "Words only the save has.")
	assert_eq(loaded.people["hinrich"][0], "husband")


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


func test_a_version_22_villager_written_by_hand_takes_their_sheet_as_written_now() -> void:
	var game := _current_game()
	var antje := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())
	antje.add_chat_line(1, 600, true, "Moin")
	var saved := _version_22_npc(antje)
	saved["background"] = "Married to Hinrich Boysen. They have three children."
	saved["habits"] = 'Says "Aye" and talks of "my Hinrich".'
	game["npcs"] = [saved]
	_write_save(22, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.find("antje")

	var written := VillagerRules.default_rules().villager("antje")
	assert_eq(loaded.background, written["background"])
	assert_eq(loaded.habits, written["habits"])
	assert_eq(loaded.speech, written["speech"])
	assert_eq(loaded.people.keys(), written["people"].keys())
	assert_eq(loaded.name, "Antje Boysen")
	assert_eq(loaded.chat_history.size(), 1, "the chat is kept")


func test_a_version_22_made_up_villager_is_made_up_anew_by_their_name() -> void:
	var game := _current_game()
	var npc := Npc.create(42, Vector2.ZERO, NpcRules.default_rules())
	var saved := _version_22_npc(npc)
	saved["habits"] = 'Says "Aye" a lot.'
	saved["trade"] = "a midwife"
	game["npcs"] = [saved, saved.duplicate(true)]
	_write_save(22, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()

	assert_eq(loaded[0].name, npc.name)
	assert_eq(loaded[0].appearance.to_dict(), npc.appearance.to_dict())
	assert_ne(loaded[0].trade, "a midwife")
	assert_false(loaded[0].habits.contains("Aye"))
	assert_gte(loaded[0].samples.size(), 2)
	assert_eq(loaded[0].people, {})
	assert_eq(loaded[0].to_dict(), loaded[1].to_dict(), "the same for the same name")


func test_a_version_22_made_up_villager_of_a_family_s_surname_is_renamed() -> void:
	var game := _current_game()
	var saved := _version_22_npc(Npc.create(42, Vector2.ZERO, NpcRules.default_rules()))
	saved["name"] = "Elke Boysen"
	saved["sex"] = "female"
	game["npcs"] = [saved, saved.duplicate(true)]
	_write_save(22, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()

	var surname := loaded[0].name.get_slice(" ", 1)
	assert_string_starts_with(loaded[0].name, "Elke ")
	assert_false(VillageSheet.default_sheet().text(true).contains(surname), surname)
	assert_eq(loaded[0].name, loaded[1].name, "the same for the same name")


## A villager as a version 22 save kept them: without the parts of the long sheet.
func _version_22_npc(npc: Npc) -> Dictionary:
	var saved := npc.to_dict()
	for key in [
		"home", "speech", "samples", "people", "likes", "wants", "day", "avoids", "secrets"
	]:
		saved.erase(key)
	return JSON.parse_string(JSON.stringify(saved))
