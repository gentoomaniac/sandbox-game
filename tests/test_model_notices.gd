extends CannedHttpTest
## What the player is told when the villagers' language model fails (ModelNotices): the chat's
## trouble from a small server here that answers as told, and the notifications it shows.

const REPLY_BODY := '{"choices": [{"message": {"role": "assistant", "content": "Aye."}}]}'
const BUSY_BODY := '{"error": {"code": 503, "message": "This model is currently busy."}}'

var _chat: OpenAiChat
var _hud: NotificationHud
var _notices: ModelNotices


func before_each() -> void:
	super()
	_chat = OpenAiChat.new()
	_hud = NotificationHud.new()
	var settings := GameSettings.new("user://test_model_notices/settings.cfg")
	var dialogue := NpcDialogue.new(settings, _chat)
	_notices = ModelNotices.new(dialogue, _hud)
	for node: Node in [dialogue, _hud, _notices]:
		add_child_autoqfree(node)


func _language_model(endpoint := "") -> Dictionary:
	if endpoint == "":
		endpoint = "http://127.0.0.1:%d/v1" % _port
	return {"endpoint": endpoint, "model": "qwen", "api_key": ""}


func _ask(response: String) -> String:
	var ask := func() -> String:
		return await _chat.answer(_language_model(), {"messages": []}, PATIENCE_SECONDS)
	return (await _ask_and_answer(ask, response))[1]


func test_a_busy_model_shows_its_message() -> void:
	await _ask(_response("503 Service Unavailable", BUSY_BODY))
	assert_eq(
		_hud.texts(),
		PackedStringArray(
			["Villagers' language model is busy (HTTP 503): This model is currently busy."]
		)
	)


func test_a_long_message_is_cut() -> void:
	var message := "x".repeat(100)
	await _ask(_response("503 Unavailable", '{"error": {"message": "%s"}}' % message))
	assert_string_ends_with(_hud.texts()[0], "x".repeat(60) + "...")


func test_a_list_wrapped_error_as_gemini_sends_it_is_read() -> void:
	await _ask(_response("503 Unavailable", '[{"error": {"message": "Overloaded"}}]'))
	assert_string_ends_with(_hud.texts()[0], ": Overloaded")


func test_a_refused_key_is_said() -> void:
	await _ask(_response("401 Unauthorized", '{"error": {"message": "Bad key"}}'))
	assert_eq(_hud.texts()[0], "Villagers' language model refused the key (HTTP 401): Bad key")


func test_an_error_without_a_message_shows_the_status_alone() -> void:
	await _ask(_response("500 Internal Server Error", "oops"))
	assert_eq(_hud.texts()[0], "Villagers' language model answered with an error (HTTP 500)")


func test_a_model_that_takes_too_long_is_said() -> void:
	# The server is listening but never answers.
	await _chat.answer(_language_model(), {"messages": []}, 0.3)
	assert_eq(_hud.texts()[0], "Villagers' language model gave no answer in time")


func test_an_endpoint_that_cannot_be_reached_is_said() -> void:
	await _chat.answer(_language_model(CLOSED_ENDPOINT), {"messages": []}, PATIENCE_SECONDS)
	assert_eq(_hud.texts()[0], "Villagers' language model is not reachable")


func test_an_empty_answer_is_said() -> void:
	var empty := '{"choices": [{"message": {"content": "  "}}]}'
	await _ask(_response("200 OK", empty))
	assert_eq(_hud.texts()[0], "Villagers' language model gave an empty answer")


func test_the_same_trouble_is_not_shown_again_for_a_while() -> void:
	await _ask(_response("503 Unavailable", BUSY_BODY))
	_hud.remove(ModelNotices.NOTE)
	await _ask(_response("503 Unavailable", BUSY_BODY))
	assert_eq(_hud.texts().size(), 0, "not again")
	_notices.repeat_seconds = 0.0
	await _ask(_response("503 Unavailable", BUSY_BODY))
	assert_eq(_hud.texts().size(), 1, "again after the time")


func test_another_trouble_replaces_the_line_at_once() -> void:
	await _ask(_response("503 Unavailable", BUSY_BODY))
	await _ask(_response("401 Unauthorized", "{}"))
	assert_eq(_hud.texts().size(), 1)
	assert_string_contains(_hud.texts()[0], "refused the key")


func test_a_quiet_line_says_it_answers_again_after_a_failure() -> void:
	await _ask(_response("503 Unavailable", BUSY_BODY))
	assert_eq(await _ask(_response("200 OK", REPLY_BODY)), "Aye.")
	assert_eq(_hud.texts(), PackedStringArray(["Villagers' language model answers again"]))


func test_a_success_without_a_failure_shows_nothing() -> void:
	await _ask(_response("200 OK", REPLY_BODY))
	assert_eq(_hud.texts().size(), 0)


func test_no_second_line_of_recovery_for_one_failure() -> void:
	await _ask(_response("503 Unavailable", BUSY_BODY))
	await _ask(_response("200 OK", REPLY_BODY))
	_hud.remove(ModelNotices.NOTE)
	await _ask(_response("200 OK", REPLY_BODY))
	assert_eq(_hud.texts().size(), 0)


func test_the_default_endpoint_is_silent_in_trouble_and_in_recovery() -> void:
	var endpoint: String = GameSettings.DEFAULT_LANGUAGE_MODEL["endpoint"]
	_chat.failed.emit(endpoint, "is not reachable", "")
	_chat.worked.emit(endpoint)
	assert_eq(_hud.texts().size(), 0)
