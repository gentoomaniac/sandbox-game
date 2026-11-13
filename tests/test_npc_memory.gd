extends ResourceCase
## What villagers remember: the lines that drop out of their chat summed up in one line (by the
## model, else plainly), a long-term memory of medium weight, capped with the lightest forgotten,
## and told in later prompts (saved: test_save_npcs.gd).

var _npc: Npc
var _settings: GameSettings
var _chat: FakeChat
var _rules := NpcTalkRules.default_rules()


func before_each() -> void:
	super.before_each()
	_npc = Npc.create_villager("antje", Vector2(_tile) + Vector2(0.5, 0.5), _state.npcs.villagers)
	_state.npcs.add(_npc)
	_settings = GameSettings.new("user://test_npc_memory/settings.cfg")
	_settings.profiles.active["endpoint"] = "http://fake/v1"
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
	screen.open_chat(_npc, _state)
	screen.say(text)
	await wait_for_signal(screen.answered, 2.0)
	screen.close()


# --- The villager's memories ---


func test_a_summed_up_chat_is_a_memory_of_medium_weight_of_today() -> void:
	_state.clock.day = 6
	_settings.profiles.set_chat_history_lines(2)
	for index in 3:
		_npc.add_chat_line(1, 400, true, "line %d" % index)
	var dialogue := NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(dialogue)
	await dialogue.compact(_npc, _state)
	assert_eq(_npc.memories.size(), 1)
	assert_eq(_npc.memories[0]["day"], 6)
	assert_eq(_npc.memories[0]["weight"], MemoryWeight.MEDIUM)


func test_the_setting_caps_the_memories() -> void:
	_settings.profiles.set_memories_kept(2)
	for index in 4:
		_npc.add_memory("day %d" % index, index, MemoryWeight.MEDIUM, 4)
	var dialogue := NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(dialogue)
	await dialogue.compact(_npc, _state)
	assert_eq(
		_npc.memories.map(func(memory: Dictionary) -> String: return memory["text"]),
		["day 2", "day 3"]
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
			+ "Neighbour: Is the dyke holding?\nAntje: Aye.\n"
			+ 'What Antje remembers of it, in one sentence that starts with "I":'
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
	var last: String = (
		NpcPrompt.reply_messages(_npc, [], "Moin", moment, _rules, false)[-1]["content"]
	)
	assert_false(last.contains("remembers"), "nothing yet")
	_npc.add_memory("On the 1st day: one.", 1, MemoryWeight.MEDIUM, 20)
	_npc.add_memory("On the 2nd day: two.", 2, MemoryWeight.MEDIUM, 20)
	last = NpcPrompt.reply_messages(_npc, [], "Moin", moment, _rules, false)[-1]["content"]
	assert_eq(
		last.split("\n")[2],
		"Antje remembers earlier talks with this neighbour: On the 1st day: one. On the 2nd day: two."
	)


# --- When lines drop out of the chat ---


func _said(screen: ChatScreen, text: String) -> void:
	screen.say(text)
	await wait_for_signal(screen.answered, 2.0)


func _texts(lines: Array[Dictionary]) -> Array:
	return lines.map(func(line: Dictionary) -> String: return line["text"])


func test_lines_beyond_the_setting_are_remembered_as_the_model_sums_them_up() -> void:
	_settings.profiles.set_chat_history_lines(2)
	_chat.answers = ["Moin!", "Aye.", "The neighbour greeted me; I greeted back."]
	var screen := _chat_screen()
	screen.open_chat(_npc, _state)
	await _said(screen, "Moin, Antje")
	assert_eq(_npc.memories.size(), 0, "both lines are still kept")
	await _said(screen, "Rain today?")
	screen.close()
	await wait_until(func() -> bool: return _npc.memories.size() == 1, 2.0)
	assert_eq(_texts(_npc.chat_history), ["Rain today?", "Aye."])
	assert_string_ends_with(_npc.memories[0]["text"], ": The neighbour greeted me; I greeted back.")
	assert_true(_npc.uncompacted_lines.is_empty())


func test_without_a_model_the_dropped_lines_are_remembered_plainly() -> void:
	_settings.profiles.active["endpoint"] = ""
	_settings.profiles.set_chat_history_lines(2)
	var screen := _chat_screen()
	screen.open_chat(_npc, _state)
	await _said(screen, "Moin, Antje")
	await _said(screen, "Rain today?")
	assert_eq(_npc.memories.size(), 1)
	assert_string_ends_with(_npc.memories[0]["text"], ': The neighbour said: "Moin, Antje"')


func test_closing_a_chat_makes_no_memory_and_the_chat_goes_on_when_reopened() -> void:
	_chat.answers = ["Moin!", "Aye."]
	var screen := _chat_screen()
	await _talk(screen, "Moin")
	assert_eq(_npc.memories.size(), 0)
	assert_eq(_chat.requests.size(), 1)
	await _talk(screen, "Rain today?")
	var messages: Array = _chat.requests[1]["messages"]
	assert_eq(
		messages.size(), 6, "the system line, the example, the earlier two lines, the message"
	)
	assert_string_contains(messages[3]["content"], "Moin")
	assert_eq(messages[4]["content"], "Moin!")


func test_a_summary_asked_for_is_followed_by_one_for_the_lines_that_dropped_meanwhile() -> void:
	_chat.seconds = 0.2
	_chat.answers = ["First.", "Second."]
	var dialogue := NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(dialogue)
	for index in 4:
		_npc.add_chat_line(1, 400, index % 2 == 0, "line %d" % index)
	_settings.profiles.set_chat_history_lines(2)
	dialogue.compact(_npc, _state)
	_npc.add_chat_line(1, 410, true, "line 4")
	dialogue.compact(_npc, _state)
	assert_eq(_chat.requests.size(), 1, "one summary at a time")
	await wait_until(func() -> bool: return _npc.memories.size() == 2, 3.0)
	assert_eq(_chat.requests.size(), 2)
	assert_string_contains(_chat.requests[0]["messages"][1]["content"], "line 0")
	assert_string_contains(_chat.requests[0]["messages"][1]["content"], "line 1")
	assert_string_contains(_chat.requests[1]["messages"][1]["content"], "line 2")
	assert_false(_chat.requests[1]["messages"][1]["content"].contains("line 1"))
	assert_true(_npc.uncompacted_lines.is_empty())
	assert_false(_npc.is_compacting)


func test_the_dropped_lines_are_kept_while_their_summary_is_asked_for() -> void:
	_chat.seconds = 0.2
	var dialogue := NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(dialogue)
	for index in 3:
		_npc.add_chat_line(1, 400, true, "line %d" % index)
	_settings.profiles.set_chat_history_lines(2)
	dialogue.compact(_npc, _state)
	assert_eq(_texts(_npc.uncompacted_lines), ["line 0"], "a save would hold them")
	await wait_until(func() -> bool: return _npc.memories.size() == 1, 3.0)


func test_lowering_the_setting_compacts_every_villager_at_once() -> void:
	_settings.profiles.active["endpoint"] = ""
	var dialogue := NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(dialogue)
	for index in 6:
		_npc.add_chat_line(1, 400, index % 2 == 0, "line %d" % index)
	_settings.profiles.set_chat_history_lines(4)
	dialogue.compact_all(_state)
	assert_eq(_texts(_npc.chat_history), ["line 2", "line 3", "line 4", "line 5"])
	assert_eq(_npc.memories.size(), 1)


# --- Lines a memory already holds, and a setting lowered in steps ---


func test_lines_a_memory_holds_are_dropped_without_a_new_summary() -> void:
	var dialogue := NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(dialogue)
	for index in 8:
		_npc.add_chat_line(1, 400, true, "line %d" % index)
	_npc.remembered_lines = 5
	_settings.profiles.set_chat_history_lines(3)
	await dialogue.compact(_npc, _state)
	assert_eq(_texts(_npc.chat_history), ["line 5", "line 6", "line 7"])
	assert_eq(_npc.remembered_lines, 0)
	assert_eq(_chat.requests.size(), 0, "lines already remembered are not summed up again")
	_settings.profiles.set_chat_history_lines(2)
	await dialogue.compact(_npc, _state)
	assert_eq(_chat.requests.size(), 1, "line 5 was not in a memory")
	assert_string_contains(_chat.requests[0]["messages"][1]["content"], "line 5")
	assert_false(_chat.requests[0]["messages"][1]["content"].contains("line 4"))


func test_lowering_the_setting_in_steps_then_compacting_once_makes_one_memory() -> void:
	_settings.profiles.active["endpoint"] = ""
	var dialogue := NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(dialogue)
	for index in 24:
		_npc.add_chat_line(1, 400, index % 2 == 0, "line %d" % index)
	for lines in range(23, 9, -1):
		_settings.profiles.set_chat_history_lines(lines)
	dialogue.compact_all(_state)
	assert_eq(_npc.chat_history.size(), 10)
	assert_eq(_npc.memories.size(), 1)


func test_lowering_the_setting_while_a_summary_is_in_flight_loses_and_doubles_nothing() -> void:
	_chat.seconds = 0.2
	_chat.answers = ["First.", "Second."]
	var dialogue := NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(dialogue)
	for index in 6:
		_npc.add_chat_line(1, 400, index % 2 == 0, "line %d" % index)
	_settings.profiles.set_chat_history_lines(5)
	dialogue.compact(_npc, _state)
	_settings.profiles.set_chat_history_lines(2)
	dialogue.compact_all(_state)
	assert_eq(_texts(_npc.uncompacted_lines), ["line 0", "line 1", "line 2", "line 3"])
	await wait_until(func() -> bool: return _npc.memories.size() == 2, 3.0)
	assert_eq(_texts(_npc.chat_history), ["line 4", "line 5"])
	assert_true(_npc.uncompacted_lines.is_empty())
	assert_eq(_chat.requests.size(), 2)
	var second: String = _chat.requests[1]["messages"][1]["content"]
	assert_false(second.contains("line 0"))
	for index in [1, 2, 3]:
		assert_string_contains(second, "line %d" % index)


# --- /clear ---


func test_clear_forgets_the_chat_and_the_memories_and_says_so() -> void:
	_chat.answers = ["Moin!"]
	var screen := _chat_screen()
	screen.open_chat(_npc, _state)
	await _said(screen, "Moin")
	_npc.add_memory("On the 1st day: one.", 1, MemoryWeight.MEDIUM, 20)
	_npc.uncompacted_lines.append(_line(true, "old"))
	var requests := _chat.requests.size()
	screen.say("/clear")
	assert_true(_npc.chat_history.is_empty())
	assert_true(_npc.memories.is_empty())
	assert_true(_npc.uncompacted_lines.is_empty())
	assert_eq(_chat.requests.size(), requests, "nothing was sent to the model")
	assert_eq(screen._messages.get_child_count(), 1)
	assert_eq(
		screen._messages.find_child("Notice", true, false).text,
		"* Antje Boysen forgets your talks."
	)
	await _said(screen, "Moin again")
	assert_null(screen._messages.find_child("Notice", true, false), "gone with the next line")
	assert_eq(_npc.chat_history.size(), 2, "the command was not kept as a line")


func test_other_text_with_a_slash_is_said_as_it_is() -> void:
	var screen := _chat_screen()
	screen.open_chat(_npc, _state)
	await _said(screen, "/dance")
	assert_eq(_npc.chat_history[0]["text"], "/dance")


func test_a_summary_in_flight_when_the_chat_is_cleared_makes_no_memory() -> void:
	_chat.seconds = 0.2
	var dialogue := NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(dialogue)
	for index in 3:
		_npc.add_chat_line(1, 400, true, "line %d" % index)
	_settings.profiles.set_chat_history_lines(2)
	dialogue.compact(_npc, _state)
	_npc.forget_chat()
	await wait_until(func() -> bool: return not _npc.is_compacting, 3.0)
	assert_true(_npc.memories.is_empty())
