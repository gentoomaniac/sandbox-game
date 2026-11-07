extends GutTest
## What villagers say back (NpcDialogue): a scripted line without a language model, the model's
## answer trimmed with one, a scripted line when the model fails or takes too long, all while
## the game is paused. The model is a fake (FakeChat; OpenAiChat itself: test_open_ai_chat.gd)
## except in the tests that talk to a real model, which run only when SANDBOX_LLM_URL names one
## (`make llm-up`, then SANDBOX_LLM_URL=http://127.0.0.1:11434/v1 make test).

const SETTINGS_PATH := "user://test_npc_dialogue/settings.cfg"

var _state: GameState
var _settings: GameSettings
var _antje: Npc


func before_all() -> void:
	_state = GameState.new_game(7)


func before_each() -> void:
	_settings = GameSettings.new(SETTINGS_PATH)
	# No model unless a test sets one: the default endpoint is the test LLM, which may be up.
	_settings.language_model["endpoint"] = ""
	_antje = Npc.create_villager("antje", _state.player.position, VillagerRules.default_rules())


func after_each() -> void:
	get_tree().paused = false


func _dialogue(chat: ModelChat = FakeChat.new()) -> NpcDialogue:
	var dialogue := NpcDialogue.new(_settings, chat)
	add_child_autoqfree(dialogue)
	return dialogue


func _scripted_replies() -> Array:
	return NpcTalkRules.default_rules().value("scripted", "replies")


func test_without_a_model_a_villager_says_a_scripted_line_while_the_game_is_paused() -> void:
	var dialogue := _dialogue()
	assert_false(dialogue.has_model())
	get_tree().paused = true
	var start := Time.get_ticks_msec()
	var answer: String = await dialogue.reply(_antje, [], "Is the dyke holding?", _state)
	assert_has(_scripted_replies(), answer)
	# Not the whole half second: the first frame's time counts from before `start`.
	assert_gte(Time.get_ticks_msec() - start, 250, "after a moment's thought")
	assert_eq((dialogue.chats["openai"] as FakeChat).requests.size(), 0, "the model is not asked")


func test_with_a_model_its_answer_is_said_trimmed() -> void:
	_settings.language_model["endpoint"] = "http://fake/v1"
	var chat := FakeChat.new()
	chat.answers = ['Antje: "Aye, it held. My Hinrich saw to it. And the sluice too."']
	var dialogue := _dialogue(chat)
	get_tree().paused = true
	var history: Array[Dictionary] = [
		{"day": 1, "minute": 400, "from_player": true, "text": "Moin"},
		{"day": 1, "minute": 400, "from_player": false, "text": "Moin!"},
	]
	var answer: String = await dialogue.reply(_antje, history, "The dyke?", _state)
	assert_eq(answer, "Aye, it held. My Hinrich saw to it.")
	var messages: Array = chat.requests[0]["messages"]
	assert_eq(messages.size(), 6, "the system line, the example, the chat and the message")
	assert_string_contains(messages[-1]["content"], 'Her neighbour says: "The dyke?"')
	assert_eq(chat.requests[0]["max_tokens"], 60)


func test_a_model_that_gives_nothing_gets_a_scripted_line() -> void:
	_settings.language_model["endpoint"] = "http://fake/v1"
	var chat := FakeChat.new()
	chat.answers = ['  ""  ']
	var answer: String = await _dialogue(chat).reply(_antje, [], "Moin", _state)
	assert_has(_scripted_replies(), answer)


## A dialogue with the real model of SANDBOX_LLM_URL (and SANDBOX_LLM_MODEL, if set), or null
## when there is none: the test passes without asking.
func _real_dialogue() -> NpcDialogue:
	var url := OS.get_environment("SANDBOX_LLM_URL")
	if url == "":
		pass_test("SANDBOX_LLM_URL is not set: no real model to ask")
		return null
	_settings.language_model["endpoint"] = url
	var model := OS.get_environment("SANDBOX_LLM_MODEL")
	if model != "":
		_settings.language_model["model"] = model
	return _dialogue(OpenAiChat.new())


func test_a_real_model_answers_in_character() -> void:
	var dialogue := _real_dialogue()
	if dialogue == null:
		return
	var answer: String = await dialogue.reply(
		_antje, [], "Good morning! Is the dyke holding after the storm?", _state
	)
	gut.p("Antje: %s" % answer)
	assert_does_not_have(_scripted_replies(), answer, "the model answered")
	assert_false(answer.to_lower().contains("as an ai"))


func test_a_real_model_sums_up_a_conversation() -> void:
	var dialogue := _real_dialogue()
	if dialogue == null:
		return
	_settings.set_chat_history_lines(2)
	_antje.add_chat_line(1, 400, true, "Do you have butter to sell?")
	_antje.add_chat_line(1, 400, false, "Aye, two pounds at the door.")
	_antje.add_chat_line(1, 401, true, "Thank you.")
	_antje.add_chat_line(1, 401, false, "Gern.")
	await dialogue.compact(_antje, _state)
	gut.p("Antje remembers: %s" % _antje.memories[0])
	assert_false(_antje.memories[0].contains("The neighbour said:"), "the model summed it up")


func test_gemini_is_asked_through_the_openai_compatible_chat_with_its_own_key() -> void:
	_settings.set_language_model("api_key", "sk-openai")
	_settings.set_language_model_provider("gemini")
	_settings.set_language_model("api_key", "AIza-test")
	var openai_chat := FakeChat.new()
	var claude_chat := FakeChat.new()
	var dialogue := NpcDialogue.new(_settings, openai_chat, claude_chat)
	add_child_autoqfree(dialogue)
	await dialogue.reply(_antje, [], "Hello", _state)
	assert_eq(claude_chat.language_models.size(), 0)
	assert_eq(openai_chat.language_models.size(), 1)
	assert_eq(openai_chat.language_models[0]["api_key"], "AIza-test")
	assert_string_contains(openai_chat.language_models[0]["endpoint"], "googleapis.com")


func test_the_chat_of_the_provider_is_asked_with_the_key_of_that_provider() -> void:
	_settings.set_language_model("endpoint", "http://fake/v1")
	_settings.set_language_model("api_key", "sk-openai")
	_settings.set_language_model_provider("claude")
	_settings.set_language_model("api_key", "sk-ant-test")
	var openai_chat := FakeChat.new()
	var claude_chat := FakeChat.new()
	var dialogue := NpcDialogue.new(_settings, openai_chat, claude_chat)
	add_child_autoqfree(dialogue)
	await dialogue.reply(_antje, [], "Hello", _state)
	_settings.set_language_model_provider("openai")
	await dialogue.reply(_antje, [], "Hello", _state)
	_settings.set_language_model_provider("claude")
	await dialogue.reply(_antje, [], "Hello", _state)
	assert_eq(openai_chat.language_models.size(), 1)
	assert_eq(openai_chat.language_models[0]["api_key"], "sk-openai")
	assert_eq(openai_chat.language_models[0]["endpoint"], "http://fake/v1")
	assert_eq(claude_chat.language_models.size(), 2)
	for language_model in claude_chat.language_models:
		assert_eq(language_model["api_key"], "sk-ant-test")
		assert_eq(language_model["endpoint"], "https://api.anthropic.com/v1")
