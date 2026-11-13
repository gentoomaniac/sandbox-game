extends SaveValidationCase
## The topics of the village a villager knows are saved; a save from before them (version 37) gives
## them all to the villagers written by hand and none to a made-up one.


func _saved(npc: Npc) -> Dictionary:
	return JSON.parse_string(JSON.stringify(npc.to_dict()))


func test_the_topics_a_villager_knows_are_kept() -> void:
	var state := GameState.new_game(7)
	var npc := Npc.create(42, Vector2.ZERO, state.npcs.rules)
	npc.topics.assign(["places", "money"])
	state.npcs.add(npc)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq(loaded.topics, ["places", "money"] as Array[String])


func test_a_version_37_save_gives_the_locals_every_topic_and_a_made_up_villager_none() -> void:
	var game := _current_game()
	var antje := _saved(Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules()))
	var made_up := _saved(Npc.create(42, Vector2.ZERO, NpcRules.default_rules()))
	for saved in [antje, made_up]:
		saved.erase("topics")
	game["npcs"] = [antje, made_up]
	_write_save(37, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()

	assert_eq(loaded[0].topics, VillageSheet.default_sheet().topic_names())
	assert_eq(loaded[1].topics, [] as Array[String])


func test_topics_that_are_not_texts_are_refused() -> void:
	var game := _current_game()
	var saved := _saved(Npc.create(42, Vector2.ZERO, NpcRules.default_rules()))
	saved["topics"] = [1, "places"]
	game["npcs"] = [saved]

	var problems: Array = _refusal_of(game).problems

	assert_eq(problems, ["npcs 0 topics: should be a list of text"], str(problems))


func test_a_save_without_topics_is_refused() -> void:
	var game := _current_game()
	var saved := _saved(Npc.create(42, Vector2.ZERO, NpcRules.default_rules()))
	saved.erase("topics")
	game["npcs"] = [saved]

	assert_true(_refusal_of(game).problems.has("npcs 0: no topics"))
