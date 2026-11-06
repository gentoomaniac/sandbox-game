extends ResourceCase
## What villagers remember: a conversation summed up in one line when its chat is closed (by the
## model, else plainly), capped with the oldest merged, and told in later prompts (saved:
## test_save_npcs.gd).

var _npc: Npc
var _settings: GameSettings
var _chat: FakeChat
var _rules := NpcTalkRules.default_rules()


func before_each() -> void:
	super.before_each()
	_npc = Npc.create_villager("antje", Vector2(_tile) + Vector2(0.5, 0.5), _state.npcs.villagers)
	_state.npcs.add(_npc)
	_settings = GameSettings.new("user://test_npc_memory/settings.cfg")
	_settings.language_model["endpoint"] = "http://fake/v1"
	_chat = FakeChat.new()


func after_each() -> void:
	get_tree().paused = false
	# A chat no screen was given is not in the tree, so nothing else frees it.
	if not _chat.is_inside_tree():
		_chat.free()


func _chat_screen() -> ChatScreen:
	var screen := ChatScreen.new()
	screen.dialogue = NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(screen.dialogue)
	add_child_autoqfree(screen)
	return screen


func _line(from_player: bool, text: String) -> Dictionary:
	return {"day": 1, "minute": 400, "from_player": from_player, "text": text}


## Opens the chat, says `text`, waits for the answer and closes the chat.
func _talk(screen: ChatScreen, text: String) -> void:
	screen.open(_npc, _state)
	screen.say(text)
	await wait_for_signal(screen.answered, 2.0)
	screen.close()


# --- The villager's memories ---


func test_beyond_the_limit_the_oldest_two_memories_become_one() -> void:
	for index in Npc.MEMORY_LIMIT + 1:
		_npc.add_memory("memory %d." % index)
	assert_eq(_npc.memories.size(), Npc.MEMORY_LIMIT)
	assert_eq(_npc.memories[0], "memory 0. memory 1.")
	assert_eq(_npc.memories[-1], "memory %d." % Npc.MEMORY_LIMIT)


func test_a_merged_memory_keeps_its_end() -> void:
	for index in Npc.MEMORY_LIMIT * 20:
		_npc.add_memory("%03d %s" % [index, "x".repeat(50)])
	assert_eq(_npc.memories[0].length(), Npc.MEMORY_LENGTH)
	assert_eq(_npc.memories.size(), Npc.MEMORY_LIMIT)


func test_the_lines_since_the_last_memory_are_this_conversation() -> void:
	_npc.add_chat_line(1, 400, true, "old")
	_npc.lines_since_memory = 0
	_npc.add_chat_line(1, 410, true, "new")
	_npc.add_chat_line(1, 410, false, "Aye.")
	assert_eq(
		_npc.unremembered_lines().map(func(line: Dictionary) -> String: return line.text),
		["new", "Aye."]
	)


# --- The prompts ---


func test_the_summary_request_tells_the_conversation() -> void:
	var lines: Array[Dictionary] = [_line(true, "Is the dyke holding?"), _line(false, "Aye.")]
	var request := NpcPrompt.memory_request(_npc, lines, _rules)
	var messages: Array = request["messages"]
	assert_eq(messages.size(), 2)
	assert_eq(messages[0]["role"], "system")
	assert_eq(
		messages[1]["content"],
		(
			"Villager: Antje Boysen, a farmer's wife.\nThe conversation:\n"
			+ "Neighbour: Is the dyke holding?\nAntje: Aye.\nWhat Antje remembers of it:"
		)
	)
	assert_eq(request["max_tokens"], 40)


func test_without_a_model_the_memory_is_the_start_of_what_the_player_said() -> void:
	var lines: Array[Dictionary] = [_line(true, "Is the dyke holding?"), _line(false, "Aye.")]
	assert_eq(NpcPrompt.plain_memory(lines, _rules), 'The neighbour said: "Is the dyke holding?"')
	lines = [_line(true, "word ".repeat(100))]
	assert_lt(NpcPrompt.plain_memory(lines, _rules).length(), 160)


func test_a_memory_is_dated() -> void:
	_state.clock.day = 12
	assert_eq(
		NpcPrompt.dated_memory("The neighbour asked after the dyke.", _state.clock, _rules),
		"On the 12th day of Spring, year 1 (mid spring): The neighbour asked after the dyke."
	)


func test_later_prompts_tell_what_the_villager_remembers() -> void:
	var moment := NpcMoment.of(_state, _npc, 8.0)
	var last: String = NpcPrompt.reply_messages(_npc, [], "Moin", moment, _rules)[-1]["content"]
	assert_false(last.contains("remembers"), "nothing yet")
	_npc.add_memory("On the 1st day: one.")
	_npc.add_memory("On the 2nd day: two.")
	last = NpcPrompt.reply_messages(_npc, [], "Moin", moment, _rules)[-1]["content"]
	assert_eq(
		last.split("\n")[2],
		"Antje remembers earlier talks with this neighbour: On the 1st day: one. On the 2nd day: two."
	)


# --- When a chat is closed ---


func test_closing_a_chat_remembers_it_as_the_model_sums_it_up() -> void:
	_chat.answers = ["Moin!", "The neighbour greeted me; I greeted back."]
	var screen := _chat_screen()
	await _talk(screen, "Moin, Antje")
	await wait_until(func() -> bool: return _npc.memories.size() == 1, 2.0)
	assert_eq(_npc.memories.size(), 1)
	assert_string_ends_with(_npc.memories[0], ": The neighbour greeted me; I greeted back.")
	assert_string_contains(_chat.requests[1]["messages"][1]["content"], "Neighbour: Moin, Antje")


func test_without_a_model_the_chat_is_remembered_plainly() -> void:
	_settings.language_model["endpoint"] = ""
	var screen := _chat_screen()
	await _talk(screen, "Moin, Antje")
	assert_eq(_npc.memories.size(), 1)
	assert_string_ends_with(_npc.memories[0], ': The neighbour said: "Moin, Antje"')


func test_a_chat_with_nothing_said_is_not_remembered() -> void:
	var screen := _chat_screen()
	screen.open(_npc, _state)
	screen.close()
	assert_eq(_npc.memories.size(), 0)
	assert_eq(_chat.requests.size(), 0)


func test_a_chat_left_before_the_answer_is_remembered_with_it() -> void:
	_chat.answers = ["Aye, it held.", "Asked about the dyke."]
	_chat.seconds = 0.2
	var screen := _chat_screen()
	screen.open(_npc, _state)
	screen.say("The dyke?")
	screen.close()
	assert_eq(_chat.requests.size(), 1, "no summary while the answer is owed")
	await wait_until(func() -> bool: return _npc.memories.size() == 1, 2.0)
	assert_string_contains(_chat.requests[1]["messages"][1]["content"], "Antje: Aye, it held.")


func test_the_next_conversation_still_tells_the_earlier_lines_and_the_memory() -> void:
	_chat.answers = ["Moin!", "We greeted.", "Aye."]
	var screen := _chat_screen()
	await _talk(screen, "Moin")
	await wait_until(func() -> bool: return _npc.memories.size() == 1, 2.0)
	await _talk(screen, "Rain today?")
	var messages: Array = _chat.requests[2]["messages"]
	assert_eq(
		messages.size(), 6, "the system line, the example, the earlier two lines, the message"
	)
	assert_string_contains(messages[3]["content"], "Moin")
	assert_eq(messages[4]["content"], "Moin!")
	assert_string_contains(messages[-1]["content"], "remembers earlier talks")
