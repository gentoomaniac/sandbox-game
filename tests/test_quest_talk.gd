extends QuestsCase
## Taking a quest (QuestTalk): speaking to the giver says the lines of the quest and takes it, and
## a full quest log refuses it.


func _lines_said_by(npc: Npc) -> Array[String]:
	var lines: Array[String] = []
	for entry in npc.chat_history:
		lines.append(entry["text"])
	return lines


func _dialogue_of(id: String) -> Array[String]:
	var lines: Array[String] = []
	lines.assign(_quests.rules.quest(id)["dialogue"])
	return lines


func test_speaking_to_the_giver_says_the_dialogue_and_takes_the_quest() -> void:
	_use_rules({"a": {}})
	_quests.post("a", ANTJE)
	var antje := _state.npcs.find(ANTJE)

	assert_eq(QuestTalk.greet_and_say(_state, antje), "")

	assert_eq(_lines_said_by(antje), _dialogue_of("a"))
	assert_true(_quests.entry_of_giver(ANTJE)["is_taken"])
	assert_false(antje.chat_history[0]["from_player"])


func test_speaking_to_another_villager_says_nothing_and_takes_nothing() -> void:
	_use_rules({"a": {}})
	_quests.post("a", ANTJE)
	var gesche := _state.npcs.find(GESCHE)

	assert_eq(QuestTalk.greet_and_say(_state, gesche), "")

	assert_true(gesche.chat_history.is_empty())
	assert_false(_quests.entry_of_giver(ANTJE)["is_taken"])


func test_speaking_again_recalls_the_first_line_once() -> void:
	_use_rules({"a": {}})
	_quests.post("a", ANTJE)
	var antje := _state.npcs.find(ANTJE)
	QuestTalk.greet_and_say(_state, antje)

	QuestTalk.greet_and_say(_state, antje)
	var recalled := _dialogue_of("a") + [_dialogue_of("a")[0]]
	assert_eq(_lines_said_by(antje), recalled, "the second line was the last said")
	QuestTalk.greet_and_say(_state, antje)

	assert_eq(antje.chat_history.size(), recalled.size(), "the reminder is the last line already")


func test_a_full_quest_log_refuses_the_quest() -> void:
	_use_rules({"a": {}, "b": {}}, {}, 1)
	_quests.post("a", ANTJE)
	_quests.post("b", GESCHE)
	var gesche := _state.npcs.find(GESCHE)
	QuestTalk.greet_and_say(_state, _state.npcs.find(ANTJE))

	assert_true(_quests.is_log_full())
	assert_eq(QuestTalk.greet_and_say(_state, gesche), QuestTalk.LOG_FULL_TEXT)

	assert_true(gesche.chat_history.is_empty())
	assert_false(_quests.entry_of_giver(GESCHE)["is_taken"])
