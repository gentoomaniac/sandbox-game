extends SaveUpgradeCase
## The console's `killall` command: it takes every animal of a kind, or one villager, out of the
## running game and out of the state that is saved, and says how many.

var _state: GameState
var _console: Console


func before_each() -> void:
	_state = GameState.new_game(7)
	_console = Console.new(_state)


func _save_and_load() -> GameState:
	assert_true(SaveFile.write(_state, SAVE_PATH))
	return SaveFile.read(SAVE_PATH)


func _add_villagers() -> void:
	for villager_id in ["antje", "hinrich"]:
		_state.npcs.add(Npc.create_villager(villager_id, Vector2.ZERO, _state.npcs.villagers))


func test_a_farm_animal_kind_is_removed_and_counted() -> void:
	_console.run("spawn cow 3")
	_console.run("spawn sheep")
	assert_eq(_console.run("killall cow"), ["Removed 3 cow"] as Array[String])
	assert_eq(_state.livestock.all().size(), 1)
	assert_eq(_state.livestock.all()[0].species, LivestockRules.SHEEP)


func test_a_pet_is_removed() -> void:
	_console.run("spawn dog 2")
	_console.run("spawn cat")
	assert_eq(_console.run("killall dog"), ["Removed 2 dog"] as Array[String])
	assert_eq(_state.livestock.all()[0].species, LivestockRules.CAT)


func test_a_kind_with_none_removes_nothing() -> void:
	assert_eq(_console.run("killall cow"), ["No cow to remove"] as Array[String])


func test_the_removed_are_not_in_the_save_that_is_loaded() -> void:
	_console.run("spawn cow 2")
	_console.run("spawn cat")
	_console.run("killall cow")
	var loaded := _save_and_load()
	assert_eq(loaded.livestock.all().size(), 1)
	assert_eq(loaded.livestock.all()[0].species, LivestockRules.CAT)


func test_a_wild_animal_is_cleared_by_the_view_and_the_answer_says_it_may_return() -> void:
	var asked := []
	_console.wildlife_clearer = func(kind: StringName) -> int:
		asked.append(kind)
		return 4
	var lines := _console.run("killall deer")
	assert_eq(asked, [WildlifeRules.DEER])
	assert_string_contains(lines[0], "Removed 4 deer")
	assert_string_contains(lines[0], "more may come")


func test_the_wild_rabbit_is_the_wild_kind_and_rabbit_the_tame_one() -> void:
	var asked := []
	_console.wildlife_clearer = func(kind: StringName) -> int:
		asked.append(kind)
		return 1
	_console.run("spawn rabbit")
	_console.run("killall wild_rabbit")
	assert_eq(asked, [WildlifeRules.RABBIT])
	assert_eq(_state.livestock.all().size(), 1)
	_console.run("killall rabbit")
	assert_eq(_state.livestock.all().size(), 0)


func test_a_villager_is_removed_by_id_and_the_others_stay() -> void:
	_add_villagers()
	assert_eq(_console.run("killall npc antje"), ["Removed Antje Boysen"] as Array[String])
	assert_null(_state.npcs.find("antje"))
	assert_not_null(_state.npcs.find("hinrich"))


func test_a_villager_is_removed_by_the_id_alone_as_spawn_takes_it() -> void:
	_add_villagers()
	_console.run("killall hinrich")
	assert_null(_state.npcs.find("hinrich"))


func test_a_villager_that_is_not_in_the_world_is_said_so() -> void:
	assert_eq(_console.run("killall npc antje"), ["antje is not in the world"] as Array[String])


func test_killall_npc_alone_removes_the_made_up_villagers_and_keeps_the_named() -> void:
	_add_villagers()
	_console.run("spawn npc 3")
	assert_eq(_state.npcs.all().size(), 5)
	var lines := _console.run("killall npc")
	assert_eq(_state.npcs.all().size(), 2)
	assert_not_null(_state.npcs.find("antje"))
	assert_string_contains(lines[0], "Removed 3 npc")
	assert_string_contains(lines[0], "killall npc <id>")
	assert_string_contains(lines[0], "antje, hinrich")


func test_killall_npc_alone_with_none_made_up_says_so() -> void:
	assert_eq(
		_console.run("killall npc"),
		["No npc to remove (the named villagers stay: killall npc <id>)"] as Array[String]
	)


func test_the_made_up_villagers_are_not_in_the_save_that_is_loaded() -> void:
	_add_villagers()
	_console.run("spawn npc 2")
	_console.run("killall npc")
	var loaded := _save_and_load()
	assert_eq(loaded.npcs.all().size(), 2)
	assert_not_null(loaded.npcs.find("antje"))


func test_an_unknown_villager_lists_the_ids() -> void:
	var lines := _console.run("killall npc nobody")
	assert_eq(lines[0], "Unknown villager: nobody")
	assert_string_contains("\n".join(lines), "antje")


func test_the_save_loads_after_a_villager_is_removed_and_nothing_names_them() -> void:
	_add_villagers()
	_state.npcs.find("antje").add_chat_line(3, 495, true, "hello")
	_console.run("killall npc antje")
	var loaded := _save_and_load()
	assert_eq(loaded.npcs.all().size(), 1)
	assert_null(loaded.npcs.find("antje"))
	assert_false(FileAccess.get_file_as_string(SAVE_PATH).contains("hello"), "her chat is gone")
	# Hinrich's family still names her: the sheet of the file speaks of her, not the world.
	var hinrich := loaded.npcs.find("hinrich")
	var prompt := NpcPrompt.system_text(hinrich, true, NpcTalkRules.default_rules())
	assert_false(prompt.is_empty())


func test_nothing_of_the_removed_is_left_in_the_state() -> void:
	_console.run("spawn cat 2")
	_console.run("killall cat")
	assert_eq(_state.livestock.all().size(), 0)
	assert_eq(_state.livestock.to_array().size(), 0)


func test_a_ridden_horse_is_not_removed_and_the_player_stays_on_it() -> void:
	_console.run("spawn horse 2")
	var horse := _state.livestock.all()[0]
	horse.is_saddled = true
	_state.mount(horse)
	var refusal: Array[String] = ["You are riding a horse: get off first"]
	assert_eq(_console.run("killall horse"), refusal)
	assert_eq(_state.livestock.all().size(), 2)
	assert_eq(_state.player.horse, horse)
	assert_true(_state.dismount())
	assert_eq(_console.run("killall horse"), ["Removed 2 horse"] as Array[String])


func test_an_unknown_kind_is_named_and_the_list_follows() -> void:
	var lines := _console.run("killall unicorn")
	assert_eq(lines[0], "Unknown animal: unicorn")
	assert_string_contains("\n".join(lines), "squirrel")


func test_killall_alone_lists_the_kinds_and_too_many_words_show_the_usage() -> void:
	assert_string_contains("\n".join(_console.run("killall")), "wild_rabbit")
	assert_string_contains(_console.run("killall cow 3")[0], "Usage: killall")


func test_killall_completes_as_spawn_does() -> void:
	assert_eq(_console.complete("killall co"), "killall cow ")
	assert_eq(_console.complete("killall wi"), "killall wild_rabbit ")
	assert_eq(_console.complete("kill"), "killall ")
	assert_eq(_console.complete("killall npc an"), "killall npc antje ")
	assert_eq(_console.complete("killall hi"), "killall hinrich ")
	assert_eq(_console.complete("help killa"), "help killall ")
