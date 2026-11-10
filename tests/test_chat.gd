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
func _chat_screen(seconds := 0.1, answer := "Aye.") -> ChatScreen:
	var screen := ChatScreen.new()
	var settings := GameSettings.new("user://test_chat/settings.cfg")
	settings.profiles.active["endpoint"] = "http://fake/v1"
	var chat := FakeChat.new()
	chat.seconds = seconds
	chat.answers = [answer]
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
	screen.open_chat(_npc, _state)
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
	screen.open_chat(_npc, _state)
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
	screen.open_chat(_npc, _state)
	screen.say("One")
	screen.say("Two")
	await wait_for_signal(screen.answered, 2.0)
	assert_eq(_npc.chat_history.size(), 2)
	screen.close()


func test_a_failed_request_takes_away_the_dots_and_leaves_the_player_free_to_write() -> void:
	var screen := _chat_screen(0.1, "")
	screen.open_chat(_npc, _state)
	screen.say("One")
	assert_eq(screen._messages.get_child_count(), 3, "the day, the line and the dots")
	await wait_for_signal(screen.answered, 2.0)
	assert_eq(screen._messages.get_child_count(), 2, "the day and the line: no dots, no answer")
	assert_eq(_npc.chat_history.size(), 1)
	assert_false(_npc.is_answering)
	screen.say("Two")
	assert_eq(_npc.chat_history.size(), 2, "and a line may be said again")
	await wait_for_signal(screen.answered, 2.0)
	screen.close()


func test_the_answer_is_kept_when_the_player_leaves_before_it_comes() -> void:
	var screen := _chat_screen()
	screen.open_chat(_npc, _state)
	screen.say("Farewell")
	screen.close()
	await wait_for_signal(screen.answered, 2.0)
	assert_eq(_npc.chat_history.size(), 2)


func test_leaving_a_villager_who_is_answering_leaves_another_free_to_talk() -> void:
	var screen := _chat_screen(0.3)
	var other := Npc.create(6, _npc.position + Vector2(1, 0), _state.npcs.rules)
	_state.npcs.add(other)
	screen.open_chat(_npc, _state)
	screen.say("One")
	assert_eq(screen._messages.get_child_count(), 3, "the day, the line and the dots")
	screen.close()
	screen.open_chat(other, _state)
	assert_eq(screen._messages.get_child_count(), 0, "the other one owes no answer")
	screen.say("Two")
	assert_eq(other.chat_history.size(), 1, "and may be spoken to")
	await wait_for_signal(screen.answered, 2.0)
	assert_eq(
		screen._messages.get_child_count(),
		3,
		"the day, the line and the dots: not the first answer"
	)
	# GUT's waiting stands still while the game is paused.
	screen.close()
	await wait_until(func() -> bool: return not other.is_answering, 2.0)
	assert_eq(_npc.chat_history.size(), 2, "the first answer is in the first chat")
	assert_eq(other.chat_history.size(), 2)


func test_the_held_key_that_opened_the_chat_types_nothing_until_it_is_let_go() -> void:
	var screen := _chat_screen()
	Input.action_press("interact")
	screen.open_chat(_npc, _state)
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
	screen.open_chat(_npc, _state)
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
	screen.open_chat(_npc, _state)
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


func test_opening_the_chat_closes_the_open_window_and_the_chat_is_a_window() -> void:
	var crafting := CraftingScreen.new()
	add_child_autofree(crafting)
	crafting.show_crafting(Crafting.new(_state), _state.player.inventory)
	crafting.open()
	var screen := _chat_screen()
	screen.open_chat(_npc, _state)
	assert_false(crafting.is_open())
	assert_true(Modal.is_any_open())
	screen.close()
	assert_false(Modal.is_any_open())


func test_opening_the_chat_again_moves_it_to_the_other_villager() -> void:
	var screen := _chat_screen()
	var other := Npc.create(6, _npc.position + Vector2(1, 0), _state.npcs.rules)
	_state.npcs.add(other)
	screen.open_chat(_npc, _state)
	screen.open_chat(other, _state)
	assert_true(screen.is_open())
	assert_true(get_tree().paused)
	assert_eq(screen._npc_name.text, other.name)
	screen.close()


## Pushes a key into a window of its own, so the input goes where a player's would.
func _press_in_window(screen: ChatScreen, key: Key) -> Array:
	var window := SubViewport.new()
	add_child_autofree(window)
	var seen_by_game := GameKeyProbe.new()
	window.add_child(seen_by_game)
	remove_child(screen)
	window.add_child(screen)
	screen.open_chat(_npc, _state)
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.unicode = key + 32
	event.pressed = true
	window.push_input(event)
	return [seen_by_game.keys_seen, screen._input.text]


class GameKeyProbe:
	extends Node
	var keys_seen := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey:
			keys_seen += 1


func test_a_game_key_typed_in_the_line_neither_closes_the_chat_nor_reaches_the_game() -> void:
	for key: Key in [KEY_E, KEY_C, KEY_K]:
		var screen := _chat_screen()
		var result := _press_in_window(screen, key)
		assert_true(screen.is_open(), "the chat stays open for %s" % OS.get_keycode_string(key))
		assert_eq(result[0], 0, "the game does not see the key")
		assert_eq(result[1], char(key + 32), "it is typed")
		screen.close()


func test_escape_leaves_the_chat_also_with_the_pause_key_rebound() -> void:
	var pause_events := InputMap.action_get_events("pause")
	InputMap.action_erase_events("pause")
	var screen := _chat_screen()
	screen.open_chat(_npc, _state)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	screen._on_input_gui_input(escape)
	for event in pause_events:
		InputMap.action_add_event("pause", event)
	assert_false(screen.is_open())
