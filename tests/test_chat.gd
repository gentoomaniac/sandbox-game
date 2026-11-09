extends ResourceCase
## Speaking to a villager: which one E speaks to (before any chest, station or bed), and the chat
## screen, its lines and the pause it holds the game in, and the wait for an answer, which is the
## villager's.

var _npc: Npc


func before_each() -> void:
	super.before_each()
	# The player stands above the grass tile, facing down onto it.
	_npc = Npc.create(5, Vector2(_tile) + Vector2(0.5, 0.5), _state.npcs.rules)
	_state.npcs.add(_npc)


func after_each() -> void:
	get_tree().paused = false


## A chat screen whose villagers answer through a fake language model after `seconds`.
func _chat_screen(seconds := 0.1) -> ChatScreen:
	var screen := ChatScreen.new()
	var settings := GameSettings.new("user://test_chat/settings.cfg")
	settings.profiles.active["endpoint"] = "http://fake/v1"
	var chat := FakeChat.new()
	chat.seconds = seconds
	screen.dialogue = NpcDialogue.new(settings, chat)
	add_child_autofree(screen.dialogue)
	add_child_autofree(screen)
	return screen


# --- Whom E speaks to ---


func test_e_speaks_to_the_villager_on_the_targeted_tile() -> void:
	assert_eq(Interaction.npc_to_chat(_state, _tile), _npc)


func test_e_speaks_to_a_villager_just_in_front_off_the_targeted_tile() -> void:
	_npc.position += Vector2(0.6, 0.3)
	assert_eq(Interaction.npc_to_chat(_state, _tile + Vector2i(-1, 0)), _npc)


func test_e_does_not_speak_to_a_villager_behind_or_too_far() -> void:
	_state.player.facing = Vector2i.UP
	assert_null(Interaction.npc_to_chat(_state, _state.player.facing_tile()))
	_state.player.facing = Vector2i.DOWN
	_npc.position += Vector2(0, 2)
	assert_null(Interaction.npc_to_chat(_state, _tile))


func test_the_villager_comes_before_a_chest_and_a_bed_in_reach() -> void:
	var chest := WorldObject.new(WorldObjectTypes.CHEST, _tile + Vector2i(1, -1))
	_world.add_object(chest)
	assert_eq(Interaction.object_to_open(_state, _tile), chest, "the chest is in reach")
	_world.add_object(WorldObject.new(WorldObjectTypes.SLEEPING_BAG, _tile + Vector2i(-1, -2)))
	assert_not_null(_state.bed_in_reach(), "and a bed")
	assert_eq(Interaction.npc_to_chat(_state, _tile), _npc)


# --- The chat screen ---


func test_the_chat_pauses_the_game_until_it_is_closed() -> void:
	var screen := _chat_screen()
	assert_false(screen.is_open())
	screen.open(_npc, _state)
	assert_true(screen.is_open())
	assert_true(get_tree().paused)
	screen.close()
	assert_false(screen.is_open())
	assert_false(get_tree().paused)
	screen.close()
	assert_false(get_tree().paused, "closing when closed")


func test_a_line_said_is_answered_and_both_are_kept_with_the_game_time() -> void:
	var screen := _chat_screen()
	_state.clock.set_time(8, 15)
	screen.open(_npc, _state)
	screen.say("Good morning")
	assert_eq(_npc.chat_history.size(), 1, "the answer is awaited")
	await wait_for_signal(screen.answered, 2.0)
	assert_eq(_npc.chat_history.size(), 2)
	assert_eq(_npc.chat_history[0]["text"], "Good morning")
	assert_true(_npc.chat_history[0]["from_player"])
	assert_eq(_npc.chat_history[1]["text"], "Aye.")
	assert_eq(_npc.chat_history[1]["minute"], 8 * 60 + 15)
	screen.close()


func test_nothing_more_is_sent_while_an_answer_is_awaited() -> void:
	var screen := _chat_screen()
	screen.open(_npc, _state)
	screen.say("One")
	screen.say("Two")
	await wait_for_signal(screen.answered, 2.0)
	assert_eq(_npc.chat_history.size(), 2)
	screen.close()


func test_the_answer_is_kept_when_the_player_leaves_before_it_comes() -> void:
	var screen := _chat_screen()
	screen.open(_npc, _state)
	screen.say("Farewell")
	screen.close()
	await wait_for_signal(screen.answered, 2.0)
	assert_eq(_npc.chat_history.size(), 2)


func test_leaving_a_villager_who_is_answering_leaves_another_free_to_talk() -> void:
	var screen := _chat_screen(0.3)
	var other := Npc.create(6, _npc.position + Vector2(1, 0), _state.npcs.rules)
	_state.npcs.add(other)
	screen.open(_npc, _state)
	screen.say("One")
	assert_eq(screen._messages.get_child_count(), 2, "the line and the dots")
	screen.close()
	screen.open(other, _state)
	assert_eq(screen._messages.get_child_count(), 0, "the other one owes no answer")
	screen.say("Two")
	assert_eq(other.chat_history.size(), 1, "and may be spoken to")
	await wait_for_signal(screen.answered, 2.0)
	assert_eq(screen._messages.get_child_count(), 2, "the first answer is not shown here")
	# GUT's waiting stands still while the game is paused.
	screen.close()
	await wait_until(func() -> bool: return not other.is_answering, 2.0)
	assert_eq(_npc.chat_history.size(), 2, "the first answer is in the first chat")
	assert_eq(other.chat_history.size(), 2)


func test_the_held_key_that_opened_the_chat_types_nothing_until_it_is_let_go() -> void:
	var screen := _chat_screen()
	Input.action_press("interact")
	screen.open(_npc, _state)
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	key.echo = true
	assert_true(key.is_action("interact"))
	screen._input.gui_input.emit(key)
	assert_true(screen._is_opening_key_held, "a repeat of the held key is swallowed")
	key.pressed = false
	key.echo = false
	screen._input.gui_input.emit(key)
	Input.action_release("interact")
	assert_false(screen._is_opening_key_held, "let go: E types again")
	screen.close()


func test_escape_closes_the_chat_and_goes_no_further() -> void:
	var screen := _chat_screen()
	screen.open(_npc, _state)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	assert_true(escape.is_action_pressed("pause"))
	screen._input.gui_input.emit(escape)
	assert_false(screen.is_open())
	assert_false(get_tree().paused)


func test_the_art_switch_key_is_passed_on_from_the_open_chat() -> void:
	var screen := _chat_screen()
	screen.open(_npc, _state)
	watch_signals(screen)
	var f7 := InputEventKey.new()
	f7.keycode = KEY_F7
	f7.physical_keycode = KEY_F7
	f7.pressed = true
	assert_true(f7.is_action_pressed("toggle_art_set"))
	screen._input.gui_input.emit(f7)
	assert_signal_emitted(screen, "art_set_switch_pressed")
	assert_eq(screen._input.text, "")
	assert_true(screen.is_open())
	screen.close()
