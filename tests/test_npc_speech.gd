extends GutTest
## The bubbles over villagers (NpcSpeech): one a minute or so, by a villager in view, at most one
## on screen; asked of the language model quietly and dropped if the villager has left the view
## by then; scripted without a model. The model is a fake (FakeChat), the camera a Callable.

const SETTINGS_PATH := "user://test_npc_speech/settings.cfg"
const MINUTE := 91.0

var _state: GameState
var _settings: GameSettings
var _chat: FakeChat
var _speech: NpcSpeech
var _antje: Npc
var _rules := NpcTalkRules.default_rules()
## The part of the world the camera shows, in art pixels.
var _region: Rect2


func before_each() -> void:
	_region = _everything_in_view()
	_state = GameState.new_game(7)
	_settings = GameSettings.new(SETTINGS_PATH)
	_settings.profiles.active["endpoint"] = ""
	_chat = FakeChat.new()
	var dialogue := NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(dialogue)
	_speech = NpcSpeech.new()
	add_child_autoqfree(_speech)
	_speech.show_for(
		_state, dialogue, func() -> Rect2: return _region, func(p: Vector2) -> Vector2: return p
	)
	_antje = Npc.create_villager("antje", Vector2(10, 10), VillagerRules.default_rules())
	_state.npcs.add(_antje)


func _everything_in_view() -> Rect2:
	return Rect2(-1000, -1000, 2000, 2000)


func _with_model() -> void:
	_settings.profiles.active["endpoint"] = "http://fake/v1"


func _scripted_lines() -> Array:
	var lines := []
	for key: String in ["weather", "part_of_day", "near_player"]:
		for list: Array in _rules.value("bubble_lines", key).values():
			lines.append_array(list)
	return lines


func test_a_villager_in_view_says_a_scripted_line_after_about_a_minute_without_a_model() -> void:
	_speech._process(10.0)
	assert_eq(_speech.shown_line(), "", "not yet")
	_speech._process(MINUTE)
	assert_has(_scripted_lines(), _speech.shown_line())


func test_the_bubble_goes_after_a_few_seconds_and_the_next_comes_a_minute_later() -> void:
	_speech._process(MINUTE)
	assert_ne(_speech.shown_line(), "")
	_speech._process(float(_rules.value("bubble", "show_seconds")) + 0.1)
	assert_eq(_speech.shown_line(), "")
	_speech._process(10.0)
	assert_eq(_speech.shown_line(), "", "a new wait began when the line was said")
	_speech._process(MINUTE)
	assert_ne(_speech.shown_line(), "")


func test_only_one_bubble_is_on_screen() -> void:
	var momme := Npc.create_villager("momme", Vector2(12, 10), VillagerRules.default_rules())
	_state.npcs.add(momme)
	_speech._process(MINUTE)
	var line := _speech.shown_line()
	for round in 10:
		_speech._process(0.4)
		assert_eq(_speech.shown_line(), line)


func test_nobody_speaks_while_no_villager_is_in_view_and_one_does_when_it_comes_into_view() -> void:
	_region = Rect2(5000, 5000, 100, 100)
	_speech._process(MINUTE)
	assert_eq(_speech.shown_line(), "")
	_region = _everything_in_view()
	_speech._process(0.1)
	assert_ne(_speech.shown_line(), "")


func test_the_bubble_goes_when_the_villager_leaves_the_view() -> void:
	_speech._process(MINUTE)
	assert_ne(_speech.shown_line(), "")
	_region = Rect2(5000, 5000, 100, 100)
	_speech._process(0.1)
	assert_eq(_speech.shown_line(), "")


func test_the_model_is_asked_quietly_at_the_chat_temperature_and_its_line_is_shown() -> void:
	_with_model()
	_settings.profiles.set_value("temperature", "1.4")
	_chat.answers = ['"The ditches will be full by noon."']
	_speech._process(MINUTE)
	await wait_seconds(0.2)
	assert_eq(_speech.shown_line(), "The ditches will be full by noon.")
	assert_eq(_chat.requests.size(), 1)
	assert_eq(_chat.quiet_flags, [true])
	assert_eq(_chat.requests[0]["temperature"], 1.4)


func test_no_second_request_is_made_while_one_is_out() -> void:
	_with_model()
	_chat.seconds = 0.3
	_speech._process(MINUTE)
	_speech._process(MINUTE)
	await wait_seconds(0.5)
	assert_eq(_chat.requests.size(), 1)


func test_a_line_that_comes_after_the_villager_left_the_view_is_dropped() -> void:
	_with_model()
	_chat.seconds = 0.2
	_speech._process(MINUTE)
	_region = Rect2(5000, 5000, 100, 100)
	await wait_seconds(0.4)
	assert_eq(_speech.shown_line(), "")


func test_a_model_that_fails_or_answers_too_long_means_no_bubble_and_no_scripted_line() -> void:
	_with_model()
	_chat.answers = [""]
	_speech._process(MINUTE)
	await wait_seconds(0.2)
	assert_eq(_speech.shown_line(), "")
	var too_long := "x".repeat(int(_rules.value("bubble", "max_length")) + 1)
	_chat.answers = [too_long]
	_speech._process(MINUTE)
	await wait_seconds(0.2)
	assert_eq(_speech.shown_line(), "")
	assert_eq(_chat.requests.size(), 2)


func test_a_villager_who_answers_the_player_is_not_made_to_speak() -> void:
	_antje.is_answering = true
	_speech._process(MINUTE)
	assert_eq(_speech.shown_line(), "")


func test_a_debug_run_has_a_new_bubble_at_once_after_the_last() -> void:
	_speech.is_nonstop = true
	_speech._process(0.1)
	var first := _speech.shown_line()
	assert_ne(first, "")
	_speech._process(float(_rules.value("bubble", "show_seconds")) + 0.1)
	assert_eq(_speech.shown_line(), "")
	_speech._process(0.1)
	assert_ne(_speech.shown_line(), "")


func test_a_villager_whose_bubble_would_be_cut_off_at_the_top_does_not_speak() -> void:
	var feet_y := _antje.position.y * TerrainTileset.TILE_SIZE
	var top := feet_y - SpeechBubble.TOP_ABOVE_FEET
	_region = Rect2(-1000, top + 1.0, 2000, 2000)
	_speech._process(MINUTE)
	assert_eq(_speech.shown_line(), "")
	_region = Rect2(-1000, top, 2000, 2000)
	_speech._process(0.1)
	assert_ne(_speech.shown_line(), "")
