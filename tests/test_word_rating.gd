extends GutTest
## The model rating what the player says to a villager (WordRating, NpcPrompt
## `word_rating_request`): the points of a kind or rude line, the caps of a day (requests and
## points), no model, the profile's switch, and an answer that is none of the words. The model is a
## fake (FakeChat).

const SETTINGS_PATH := "user://test_word_rating/settings.cfg"
## What the villager answers to the line; the rating is asked after it.
const REPLY := "Aye, good day."

var _state: GameState
var _antje: Npc
var _settings: GameSettings
var _chat: FakeChat
var _dialogue: NpcDialogue
var _rules := NpcTalkRules.default_rules()
var _friendship := FriendshipRules.default_rules()


func before_each() -> void:
	_state = GameState.new_game(7)
	_antje = Npc.create_villager("antje", Vector2(2.5, 2.5), _state.npcs.villagers)
	_state.npcs.add(_antje)
	# The first chat of the day has counted, so that only the ratings move the opinion.
	_antje.chat_counted_day = _state.clock.day
	_settings = GameSettings.new(SETTINGS_PATH)
	_settings.profiles.active["endpoint"] = "http://fake/v1"
	_chat = FakeChat.new()
	_dialogue = NpcDialogue.new(_settings, _chat)
	add_child_autofree(_dialogue)
	add_child_autofree(WordRating.new(_dialogue, _state))


## The player says `line` and the villager answers with REPLY; then the rating is awaited. The
## fake answers on the next frame, so a few frames wait for it however slow the machine is (a
## wait in seconds lost the race on a busy run).
func _say(line: String, rating_answer: String) -> void:
	_chat.answers = [REPLY, rating_answer]
	await _dialogue.say(_antje, line, _state)
	await wait_process_frames(5)


func _rating_requests() -> Array[Dictionary]:
	return _chat.requests.filter(
		func(request: Dictionary) -> bool:
			return request["max_tokens"] == _rules.value("word_rating", "max_tokens")
	)


func test_a_kind_line_raises_the_opinion() -> void:
	await _say("What a fine farm you keep, Antje.", "warm")

	assert_eq(_antje.opinion, _friendship.rating_points(&"warm"))
	assert_eq(_antje.ratings_today, 1)


func test_a_rude_line_lowers_it() -> void:
	await _say("You are a fool.", "rude")

	assert_eq(_antje.opinion, _friendship.rating_points(&"rude"))


func test_a_neutral_or_garbled_answer_moves_nothing_but_counts_as_a_request() -> void:
	await _say("The hay is in.", "neutral")
	await _say("Nice weather.", "Banana split, I could not say.")
	await _say("Hm.", "")

	assert_eq(_antje.opinion, 0)
	assert_eq(_antje.ratings_today, 3)


func test_the_rating_is_asked_quietly_with_the_line_and_no_history() -> void:
	await _say("What a fine farm you keep, Antje.", "warm")

	var requests := _rating_requests()
	assert_eq(requests.size(), 1)
	assert_eq(requests[0]["messages"].size(), 2, "the system line and the line, no chat")
	assert_string_contains(requests[0]["messages"][1]["content"], "What a fine farm")
	assert_eq(_chat.quiet_flags[-1], true)
	assert_eq(_chat.timeouts[-1], _rules.value("word_rating", "timeout_seconds"))


func test_with_no_model_nothing_is_asked_and_nothing_counts() -> void:
	_settings.profiles.active["endpoint"] = ""

	await _say("What a fine farm you keep, Antje.", "warm")

	assert_true(_chat.requests.is_empty())
	assert_eq(_antje.opinion, 0)
	assert_eq(_antje.ratings_today, 0)


func test_with_the_switch_off_the_reply_is_asked_but_not_the_rating() -> void:
	_settings.profiles.set_uses_model_for(&"word_rating", false)

	await _say("What a fine farm you keep, Antje.", "warm")

	assert_eq(_chat.requests.size(), 1, "the reply only")
	assert_eq(_antje.opinion, 0)


func test_a_villager_is_asked_for_a_few_ratings_a_day_only() -> void:
	var cap: int = _friendship.value("rating", "requests_per_day")
	for round in cap + 2:
		await _say("Line %d" % round, "neutral")

	assert_eq(_rating_requests().size(), cap)
	assert_eq(_antje.ratings_today, cap)


func test_the_next_day_the_requests_come_again() -> void:
	for round in _friendship.value("rating", "requests_per_day"):
		await _say("Line %d" % round, "neutral")
	_state.clock.advance(GameClock.MINUTES_PER_DAY)
	_antje.chat_counted_day = _state.clock.day

	await _say("Another day", "neutral")

	assert_eq(_antje.ratings_today, 1)


func test_kind_lines_move_the_opinion_up_to_the_cap_of_the_day() -> void:
	for round in 3:
		TalkFriendship.apply_rating(_state, _antje, &"warm")

	assert_eq(_antje.opinion, _friendship.rating_daily_cap(&"warm"))


func test_rude_lines_move_it_down_to_the_cap_of_the_day() -> void:
	for round in 3:
		TalkFriendship.apply_rating(_state, _antje, &"rude")

	assert_eq(_antje.opinion, -_friendship.rating_daily_cap(&"rude"))


func test_a_rude_line_after_a_kind_one_takes_back_what_it_may() -> void:
	TalkFriendship.apply_rating(_state, _antje, &"warm")
	TalkFriendship.apply_rating(_state, _antje, &"rude")

	assert_eq(
		_antje.opinion, _friendship.rating_points(&"warm") + _friendship.rating_points(&"rude")
	)


func test_a_new_day_has_its_own_cap_for_the_ratings() -> void:
	TalkFriendship.apply_rating(_state, _antje, &"warm")
	_state.clock.advance(GameClock.MINUTES_PER_DAY)
	TalkFriendship.apply_rating(_state, _antje, &"warm")

	assert_eq(_antje.opinion, 2 * _friendship.rating_points(&"warm"))


func test_a_rating_counts_within_the_cap_of_the_actions_too() -> void:
	_antje.change_friendship(
		_friendship.action_daily_cap(), _state.clock.day, _friendship, GossipRules.default_rules()
	)

	TalkFriendship.apply_rating(_state, _antje, &"warm")

	assert_eq(_antje.opinion, _friendship.action_daily_cap())


func test_the_answer_is_taken_by_its_first_word() -> void:
	for answer in ["warm", "Warm.", '"warm"', "  WARM  ", "warm, I think", "warm\nbecause"]:
		assert_eq(NpcPrompt.word_rating_from_answer(answer, _rules), &"warm", answer)
	assert_eq(NpcPrompt.word_rating_from_answer("rude", _rules), &"rude")
	assert_eq(NpcPrompt.word_rating_from_answer("neutral", _rules), &"neutral")


func test_an_answer_that_is_none_of_the_words_is_neutral() -> void:
	for answer in ["", "   ", "kind", "I would say warm", "level 10", "warmth"]:
		assert_eq(NpcPrompt.word_rating_from_answer(answer, _rules), &"neutral", answer)
