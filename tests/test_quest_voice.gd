extends QuestsCase
## The model's words for the lines of a quest (QuestVoice, NpcPrompt `quest_lines_request`): the
## prompt, the lines taken from the answer, the profile's "Quest lines" switch, and the fixed lines
## as the fallback. The model is a fake (FakeChat).

const SETTINGS_PATH := "user://test_quest_voice/settings.cfg"

var _settings: GameSettings
var _chat: FakeChat
var _dialogue: NpcDialogue
var _voice: QuestVoice
var _antje: Npc
var _rules := NpcTalkRules.default_rules()


func before_each() -> void:
	super.before_each()
	_settings = GameSettings.new(SETTINGS_PATH)
	_settings.profiles.active["endpoint"] = ""
	_chat = FakeChat.new()
	_dialogue = NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(_dialogue)
	_voice = QuestVoice.new(_dialogue)
	_antje = _state.npcs.find(ANTJE)
	_use_rules({"a": {}})
	_quests.post("a", ANTJE)


func _with_model() -> void:
	_settings.profiles.active["endpoint"] = "http://fake/v1"


func _said() -> Array[String]:
	var lines: Array[String] = []
	for entry in _antje.chat_history:
		lines.append(entry["text"])
	return lines


func _fixed_lines() -> Array[String]:
	return ["My bean rows sag, neighbour.", "Could you spare five fibre to bind them?"]


func _speak() -> void:
	await _voice.speak(_state, _antje, QuestTalk.greet(_state, _antje))


func test_the_prompt_gives_the_sheet_what_the_lines_are_for_and_the_lines_to_voice() -> void:
	var request := NpcPrompt.quest_lines_request(
		_antje, QuestTalk.GIVE, _fixed_lines(), _rules, true
	)

	var messages: Array = request["messages"]
	assert_eq(messages.size(), 2)
	assert_eq(messages[0]["role"], "system")
	assert_string_contains(messages[0]["content"], "exactly as many lines as you are given")
	assert_string_contains(messages[0]["content"], "never make up")
	var user: String = messages[1]["content"]
	assert_string_contains(user, "Antje Boysen, a farmer's wife")
	assert_string_contains(user, "Antje asks the newcomer for a small favour.")
	assert_string_contains(
		user, "1. My bean rows sag, neighbour.\n2. Could you spare five fibre to bind them?"
	)
	assert_true(user.ends_with("Antje's 2 lines:"), user)
	assert_eq(request["max_tokens"], int(_rules.value("quest_lines", "max_tokens")))


func test_each_part_of_a_quest_has_its_intent() -> void:
	for intent in [QuestTalk.GIVE, QuestTalk.REMIND, QuestTalk.SHORT, QuestTalk.TURN_IN]:
		var request := NpcPrompt.quest_lines_request(_antje, intent, ["Aye."], _rules, false)
		assert_string_contains(request["messages"][1]["content"], "Antje ")
		assert_false("{" in request["messages"][1]["content"], "a word left unfilled: %s" % intent)


func test_the_lines_of_an_answer_are_taken_one_for_each() -> void:
	var answer := '1. "Ach, my beans are all a-sag."\n2) Five fibre, if you can spare it.\n'

	assert_eq(
		NpcPrompt.quest_lines_from_answer(answer, _antje, 2, _rules),
		["Ach, my beans are all a-sag.", "Five fibre, if you can spare it."] as Array[String]
	)


func test_the_label_of_the_answer_and_a_bullet_are_taken_off() -> void:
	var answer := "Antje's 2 lines:\n- First.\n- Second."

	assert_eq(
		NpcPrompt.quest_lines_from_answer(answer, _antje, 2, _rules),
		["First.", "Second."] as Array[String]
	)


func test_an_answer_with_the_wrong_number_of_lines_or_a_too_long_one_is_none() -> void:
	assert_true(NpcPrompt.quest_lines_from_answer("Only one.", _antje, 2, _rules).is_empty())
	assert_true(NpcPrompt.quest_lines_from_answer("A.\nB.\nC.", _antje, 2, _rules).is_empty())
	assert_true(NpcPrompt.quest_lines_from_answer("", _antje, 2, _rules).is_empty())
	var long_line := "x".repeat(int(_rules.value("quest_lines", "max_length")) + 1)
	assert_true(NpcPrompt.quest_lines_from_answer("A.\n" + long_line, _antje, 2, _rules).is_empty())


func test_with_no_model_the_fixed_lines_are_said_at_once() -> void:
	_voice.speak(_state, _antje, QuestTalk.greet(_state, _antje))

	assert_eq(_said(), _fixed_lines())
	assert_true(_chat.requests.is_empty())
	assert_false(_antje.is_answering)


func test_with_a_model_the_villager_says_its_lines_in_their_own_words_asked_quietly() -> void:
	_with_model()
	_chat.answers = ["Oh, my bean rows are sagging.\nFive fibre would set them right."]
	var told: Array[Npc] = []
	_dialogue.answered.connect(func(npc: Npc) -> void: told.append(npc))

	await _speak()

	assert_eq(_said(), ["Oh, my bean rows are sagging.", "Five fibre would set them right."])
	assert_eq(_chat.requests.size(), 1)
	assert_eq(_chat.quiet_flags, [true])
	assert_eq(told, [_antje] as Array[Npc], "the chat is told")
	assert_false(_antje.is_answering)


func test_the_villager_is_typing_while_the_model_is_asked() -> void:
	_with_model()
	_chat.seconds = 0.2
	_chat.answers = ["A.\nB."]

	_speak()
	assert_true(_antje.is_answering)
	await wait_seconds(0.5)

	assert_false(_antje.is_answering)
	assert_eq(_said(), ["A.", "B."])


func test_the_quest_is_taken_whatever_the_model_says() -> void:
	_with_model()
	_chat.answers = ["I will have none of it."]

	await _speak()

	assert_true(_quests.entry_of_giver(ANTJE)["is_taken"], "the game decided, not the model")
	assert_eq(_said(), _fixed_lines(), "one line for two: the fixed lines are said")


func test_a_model_that_gives_nothing_means_the_fixed_lines() -> void:
	_with_model()
	_chat.answers = [""]

	await _speak()

	assert_eq(_said(), _fixed_lines())
	assert_false(_antje.is_answering)


func test_with_quest_lines_switched_off_the_model_is_not_asked() -> void:
	_with_model()
	_settings.profiles.set_uses_model_for(&"quest_lines", false)

	await _speak()

	assert_eq(_said(), _fixed_lines())
	assert_true(_chat.requests.is_empty())


func test_the_turn_in_lines_are_voiced_too_and_the_reward_stays_the_games() -> void:
	_with_model()
	QuestTalk.greet_and_say(_state, _antje)
	_antje.chat_history.clear()
	_state.player.inventory = Inventory.new()
	_state.player.inventory.add(ItemTypes.FIBRE, 5)
	_state.player.inventory.hold(ItemTypes.FIBRE)
	_chat.answers = ["That holds well.\nHere is your seed."]

	await _speak()

	assert_eq(_said(), ["That holds well.", "Here is your seed."])
	assert_true(_quests.is_done("a"))
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP_SEEDS), 10)
	assert_string_contains(_chat.requests[0]["messages"][1]["content"], "thanks the newcomer")


func test_a_reminder_is_said_once_even_when_the_model_worded_it() -> void:
	_with_model()
	QuestTalk.greet_and_say(_state, _antje)
	_chat.answers = ["Do not forget my beans."]
	_state.player.inventory = Inventory.new()

	await _speak()
	await _speak()

	assert_eq(_chat.requests.size(), 1, "asked once, said once")
	assert_eq(_said().back(), "Do not forget my beans.")
	assert_eq(_said().size(), _fixed_lines().size() + 1)
