extends ResourceCase
## The chat screen's bubbles: which side, the name and time in them, their spacing and width, the
## villager typing and the scrolling to the newest line.

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
	var settings := GameSettings.new("user://test_chat_bubbles/settings.cfg")
	settings.profiles.active["endpoint"] = "http://fake/v1"
	var chat := FakeChat.new()
	chat.seconds = seconds
	screen.dialogue = NpcDialogue.new(settings, chat)
	add_child_autofree(screen.dialogue)
	add_child_autofree(screen)
	return screen


# --- Whom E speaks to ---


## The bubbles of the chat, top to bottom (the wrappers' first child).
func _bubbles(screen: ChatScreen) -> Array[Control]:
	var bubbles: Array[Control] = []
	for message in screen._messages.get_children():
		if message.get_child(0) is not Label:
			bubbles.append(message.get_child(0))
	return bubbles


## The day lines of the chat, top to bottom.
func _day_lines(screen: ChatScreen) -> Array[String]:
	var lines: Array[String] = []
	for label in screen._messages.find_children("Date", "Label", true, false):
		lines.append(label.text)
	return lines


func _text_in(bubble: Control, part: String) -> String:
	return (bubble.find_child(part, true, false) as Label).text


func test_the_players_lines_are_on_the_right_and_the_villagers_on_the_left() -> void:
	var screen := _chat_screen()
	_npc.add_chat_line(1, 8 * 60 + 15, true, "hello")
	_npc.add_chat_line(1, 8 * 60 + 16, false, "I understand.")
	screen.open_chat(_npc, _state)
	var bubbles := _bubbles(screen)
	assert_eq(bubbles.size(), 2)
	assert_eq(bubbles[0].size_flags_horizontal, Control.SIZE_SHRINK_END)
	assert_eq(bubbles[1].size_flags_horizontal, Control.SIZE_SHRINK_BEGIN)
	screen.close()


func test_a_bubble_shows_the_text_and_the_time_and_the_villagers_also_their_name() -> void:
	var screen := _chat_screen()
	_npc.add_chat_line(1, 8 * 60 + 15, true, "hello")
	_npc.add_chat_line(1, 8 * 60 + 16, false, "I understand.")
	screen.open_chat(_npc, _state)
	var bubbles := _bubbles(screen)
	assert_eq(_text_in(bubbles[0], "Text"), "hello")
	assert_eq(_text_in(bubbles[0], "Time"), "08:15")
	assert_null(bubbles[0].find_child("Name", true, false), "the player needs no name")
	assert_eq(_text_in(bubbles[1], "Text"), "I understand.")
	assert_eq(_text_in(bubbles[1], "Time"), "08:16")
	assert_eq(_text_in(bubbles[1], "Name"), _npc.name)
	screen.close()


func test_a_run_of_one_speaker_is_named_once_and_set_closer_than_a_change_of_speaker() -> void:
	var screen := _chat_screen()
	_npc.add_chat_line(1, 480, false, "One")
	_npc.add_chat_line(1, 481, false, "Two")
	_npc.add_chat_line(1, 482, true, "Three")
	screen.open_chat(_npc, _state)
	var bubbles := _bubbles(screen)
	assert_not_null(bubbles[0].find_child("Name", true, false))
	assert_null(bubbles[1].find_child("Name", true, false))
	var gaps: Array[int] = []
	for message in screen._messages.get_children():
		gaps.append(message.get_theme_constant("margin_top"))
	# The day above them first, then the bubbles.
	assert_eq(gaps, [0, 0, ChatScreen.SAME_SPEAKER_GAP, ChatScreen.OTHER_SPEAKER_GAP])
	screen.close()


func test_a_long_line_wraps_within_most_of_the_window_width() -> void:
	var screen := _chat_screen()
	_npc.add_chat_line(1, 480, false, "word ".repeat(80))
	screen.open_chat(_npc, _state)
	await wait_frames(2)
	var bubble := _bubbles(screen)[0]
	assert_lte(bubble.size.x, ChatScreen.LOG_SIZE.x * ChatScreen.BUBBLE_MAX_SHARE)
	assert_gt(bubble.size.y, 60.0, "it is several lines high")
	screen.close()


func test_a_word_too_long_to_wrap_is_broken_within_the_width() -> void:
	var screen := _chat_screen()
	_npc.add_chat_line(1, 480, false, "x".repeat(150))
	screen.open_chat(_npc, _state)
	await wait_frames(2)
	var bubble := _bubbles(screen)[0]
	assert_lte(bubble.size.x, ChatScreen.LOG_SIZE.x * ChatScreen.BUBBLE_MAX_SHARE)
	assert_gt(bubble.size.y, 40.0, "it is several lines high")
	screen.close()


func test_a_villager_named_like_the_player_is_still_on_the_left() -> void:
	var screen := _chat_screen()
	_npc.name = ChatScreen.PLAYER_NAME
	_npc.add_chat_line(1, 480, false, "Hello")
	screen.open_chat(_npc, _state)
	assert_eq(_bubbles(screen)[0].size_flags_horizontal, Control.SIZE_SHRINK_BEGIN)
	screen.close()


func test_the_dots_are_gone_when_a_villager_who_answered_while_away_is_reopened() -> void:
	var screen := _chat_screen(0.1)
	screen.open_chat(_npc, _state)
	screen.say("One")
	screen.close()
	await wait_until(func() -> bool: return not _npc.is_answering, 2.0)
	screen.open_chat(_npc, _state)
	assert_eq(_bubbles(screen).size(), 2)
	assert_eq(_text_in(_bubbles(screen)[1], "Text"), "Aye.")
	screen.close()


func test_the_villager_typing_is_a_bubble_of_dots_without_a_time() -> void:
	var screen := _chat_screen(0.3)
	screen.open_chat(_npc, _state)
	screen.say("One")
	var bubbles := _bubbles(screen)
	assert_eq(bubbles.size(), 2)
	assert_eq(_text_in(bubbles[1], "Text"), ChatScreen.TYPING_TEXT)
	assert_null(bubbles[1].find_child("Time", true, false))
	assert_eq(bubbles[1].size_flags_horizontal, Control.SIZE_SHRINK_BEGIN)
	await wait_for_signal(screen.answered, 2.0)
	assert_eq(_bubbles(screen).size(), 2, "the dots give way to the answer")
	assert_eq(_text_in(_bubbles(screen)[1], "Text"), "Aye.")
	screen.close()


func test_the_window_scrolls_to_the_newest_line() -> void:
	var screen := _chat_screen()
	for index in 30:
		_npc.add_chat_line(1, 480 + index, index % 2 == 0, "Line %d" % index)
	screen.open_chat(_npc, _state)
	await wait_frames(2)
	var scroll_bar := screen._scroll.get_v_scroll_bar()
	assert_gt(scroll_bar.max_value, scroll_bar.page, "there is something to scroll")
	assert_almost_eq(scroll_bar.value, scroll_bar.max_value - scroll_bar.page, 1.0)
	screen.close()


func test_each_days_lines_have_the_day_above_them() -> void:
	_state.clock.day = 12
	_npc.add_chat_line(3, 600, true, "Long ago.")
	_npc.add_chat_line(11, 600, true, "Yesterday's word.")
	_npc.add_chat_line(11, 610, false, "And my answer.")
	_npc.add_chat_line(12, 480, true, "Good morning.")
	var screen := _chat_screen()
	screen.open_chat(_npc, _state)
	assert_eq(
		_day_lines(screen),
		[GameClock.date_text_of(3), "Yesterday", "Today"] as Array[String],
	)
	assert_eq(GameClock.date_text_of(3), "3rd day of Spring Year 1")
	assert_eq(GameClock.date_text_of(12), _state.clock.date_text())
	assert_eq(_bubbles(screen).size(), 4, "the day lines are not bubbles")
