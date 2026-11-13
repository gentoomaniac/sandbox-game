extends GutTest
## The queue of stories to judge is worked off one story at a time (StoryJudging): the language
## model is asked for each, its verdict settled, and anything else from it is the fixed verdict;
## without a model the fixed verdicts come at once. The model is a fake (FakeChat).

const SETTINGS_PATH := "user://test_story_judging/settings.cfg"

var _state: GameState
var _settings: GameSettings
var _chat: FakeChat
var _judging: StoryJudging
var _antje: Npc
var _rules := GossipRules.default_rules()


func before_each() -> void:
	_state = GameState.new_game(7)
	_state.clock.day = 3
	_settings = GameSettings.new(SETTINGS_PATH)
	_settings.profiles.active["endpoint"] = "http://fake/v1"
	_chat = FakeChat.new()
	var dialogue := NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(dialogue)
	_judging = StoryJudging.new(dialogue, _state)
	add_child_autoqfree(_judging)
	_antje = Npc.create_villager("antje", Vector2.ZERO, _state.npcs.villagers)
	_state.npcs.add(_antje)


## A story of 7 felled trees that `_antje` came to know at the game minute `learned_at`.
func _story(how: StringName, learned_at := 0, place := "by Antje's house") -> Dictionary:
	var story := {
		"day": 3,
		"minute": 600,
		"kind": GossipRules.FELLED,
		"count": 7,
		"place": place,
		"origin": "3|felled|" + place,
		"how": how,
		"told_by": "Moiken Ketels" if how == GossipRules.HEARD else "",
		"seen_by": "Moiken Ketels",
		"hops": 0 if how == GossipRules.SEEN else 1,
		"learned_at": learned_at,
		"line": "",
		"is_judged": false,
		"weight": MemoryWeight.MEDIUM,
		"personal": false,
	}
	_antje.stories.append(story)
	return story


func _verdict_json(change: int, is_personal := false) -> String:
	return '{"line": "Aye, I saw it.", "change": %d, "personal": %s}' % [change, is_personal]


func test_the_model_is_asked_for_each_story_and_its_verdict_settled() -> void:
	var seen := _story(GossipRules.SEEN, 100)
	var heard := _story(GossipRules.HEARD, 200, "by Momme's house")
	_chat.answers = [_verdict_json(-2, true), _verdict_json(1)]

	await _judging.judge_queue()

	assert_eq(_chat.requests.size(), 2)
	assert_true(seen["is_judged"] and heard["is_judged"])
	assert_eq([seen["line"], seen["personal"]], ["Aye, I saw it.", true])
	assert_eq(seen["weight"], MemoryWeight.HIGH)
	assert_eq([heard["personal"], heard["weight"]], [false, MemoryWeight.MEDIUM])
	assert_eq(_antje.opinion, -15, "-20 for the one seen, then +5 for the one heard")


func test_the_judge_asks_quietly_so_that_its_failures_are_not_shown_to_the_player() -> void:
	_story(GossipRules.SEEN, 100)

	await _judging.judge_queue()

	assert_eq(_chat.quiet_flags, [true] as Array[bool])


func test_the_stories_are_asked_one_at_a_time_the_one_learned_first_first() -> void:
	_story(GossipRules.SEEN, 300, "later place")
	_story(GossipRules.SEEN, 100, "earlier place")
	_chat.seconds = 0.05

	_judging.judge_queue()
	_judging.judge_queue()
	await get_tree().process_frame

	assert_eq(_chat.requests.size(), 1, "the second call leaves the queue to the one at work")
	assert_string_contains(_chat.requests[0]["messages"][1]["content"], "earlier place")
	await wait_until(func() -> bool: return _chat.requests.size() == 2, 2.0)
	assert_string_contains(_chat.requests[1]["messages"][1]["content"], "later place")


func test_the_request_tells_the_sheet_and_the_story_and_has_a_low_temperature_of_its_own() -> void:
	_settings.profiles.active["temperature"] = "1.5"
	_story(GossipRules.HEARD, 100)
	_chat.answers = [_verdict_json(0)]

	await _judging.judge_queue()

	var request: Dictionary = _chat.requests[0]
	var talk := NpcTalkRules.default_rules()
	assert_eq(request["temperature"], talk.value("judge", "temperature"))
	assert_lt(request["temperature"], 0.5)
	var user_text: String = request["messages"][1]["content"]
	assert_string_contains(user_text, "Antje Boysen, a farmer's wife")
	assert_string_contains(user_text, "Today Moiken told you that the newcomer was seen to fell")
	assert_string_contains(request["messages"][0]["content"], "JSON")


func test_a_verdict_that_is_none_is_the_fixed_one() -> void:
	var replies := ["", "Fine, fine.", '{"line": "Aye.", "change": 9, "personal": true}']
	for reply: String in replies:
		var story := _story(GossipRules.SEEN, 100, reply)
		_chat.answers = [reply]
		_antje.opinion = 0
		_antje.opinion_moved_today = 0

		await _judging.judge_queue()

		assert_true(story["is_judged"], reply)
		assert_eq(story["line"], "", reply)
		assert_false(story["personal"], reply)
		var change := _rules.opinion_change(GossipRules.FELLED)
		assert_eq(_antje.opinion, _rules.opinion_points(change, GossipRules.SEEN), reply)


func test_without_a_model_the_fixed_verdicts_come_at_once() -> void:
	_settings.profiles.active["endpoint"] = ""
	var story := _story(GossipRules.SEEN, 100)

	await _judging.judge_queue()

	assert_true(story["is_judged"])
	assert_eq(_chat.requests.size(), 0)
	assert_eq(_antje.opinion, _rules.opinion_points(-1, GossipRules.SEEN))


func test_the_opinion_stays_within_the_daily_cap_however_many_stories_are_judged() -> void:
	_settings.profiles.active["endpoint"] = ""
	for index in 6:
		_story(GossipRules.SEEN, index, "place %d" % index)

	await _judging.judge_queue()

	assert_eq(_antje.opinion, -_rules.opinion_daily_cap())


func test_a_story_judged_stays_judged() -> void:
	_story(GossipRules.SEEN, 100)
	_chat.answers = [_verdict_json(1)]
	await _judging.judge_queue()
	await _judging.judge_queue()
	assert_eq(_chat.requests.size(), 1)
