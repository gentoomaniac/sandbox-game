extends CannedHttpTest
## OpenAiChat, the client of an OpenAI-compatible chat API: the address it posts to, the request
## it sends, and what it makes of the answers of a small server here that answers as told (a
## reply, an error, broken JSON, a redirect, nothing), or of no server at all.

const REPLY_BODY := '{"choices": [{"message": {"role": "assistant", "content": "Aye, it held."}}]}'

var _chat: OpenAiChat


func before_each() -> void:
	super()
	_chat = OpenAiChat.new()
	add_child_autoqfree(_chat)


func _language_model(api_key := "") -> Dictionary:
	return {"endpoint": "http://127.0.0.1:%d/v1" % _port, "model": "qwen", "api_key": api_key}


## Asks the chat, answers its request with `response` and gives [the request as text, the
## chat's answer].
func _ask_chat(response: String, api_key := "") -> Array:
	var ask := func() -> String:
		return await _chat.answer(_language_model(api_key), {"messages": []}, PATIENCE_SECONDS)
	return await _ask_and_answer(ask, response)


func test_the_address_is_the_endpoint_with_the_chat_path() -> void:
	var expected := "http://127.0.0.1:11434/v1/chat/completions"
	assert_eq(OpenAiChat.url_of("http://127.0.0.1:11434/v1"), expected)
	assert_eq(OpenAiChat.url_of("http://127.0.0.1:11434/v1/"), expected)
	assert_eq(OpenAiChat.url_of(expected), expected)
	assert_eq(OpenAiChat.url_of("http://localhost:1234"), "http://localhost:1234/chat/completions")


func test_an_answer_is_the_text_of_its_first_choice() -> void:
	var asked := await _ask_chat(_response("200 OK", REPLY_BODY), "sk-test")
	var request: String = asked[0]
	assert_eq(asked[1], "Aye, it held.")
	assert_string_starts_with(request, "POST /v1/chat/completions HTTP/1.1")
	assert_string_contains(request, "Authorization: Bearer sk-test")
	var body: Dictionary = _body_of(request)
	assert_eq(body["model"], "qwen")
	assert_eq(body["stream"], false)
	assert_eq(body["messages"], [])


func test_the_max_tokens_set_for_the_provider_replace_the_requests() -> void:
	var language_model := _language_model()
	var sent := []
	for set_tokens in ["400", "", "lots", "0"]:
		language_model["max_tokens"] = set_tokens
		var ask := func() -> String:
			return await _chat.answer(
				language_model, {"messages": [], "max_tokens": 60}, PATIENCE_SECONDS
			)
		var asked := await _ask_and_answer(ask, _response("200 OK", REPLY_BODY))
		sent.append(int(_body_of(asked[0])["max_tokens"]))
	assert_eq(sent, [400, 60, 60, 60], "a number set, else the request's")


func test_without_a_key_no_authorization_is_sent() -> void:
	var asked := await _ask_chat(_response("200 OK", REPLY_BODY))
	assert_false(asked[0].contains("Authorization"))


func test_an_error_status_gives_no_answer() -> void:
	var asked := await _ask_chat(_response("500 Internal Server Error", '{"error": "x"}'))
	assert_eq(asked[1], "")


func test_broken_json_gives_no_answer() -> void:
	assert_eq((await _ask_chat(_response("200 OK", "{choices: ")))[1], "")
	assert_eq((await _ask_chat(_response("200 OK", '{"choices": []}')))[1], "")


func test_a_redirect_is_not_followed_so_the_key_stays_here() -> void:
	var redirect := (
		"HTTP/1.1 302 Found\r\nLocation: http://example.com/v1/chat/completions\r\n"
		+ "Content-Length: 0\r\nConnection: close\r\n\r\n"
	)
	assert_eq((await _ask_chat(redirect, "sk-test"))[1], "")


func test_an_endpoint_that_cannot_be_reached_gives_no_answer() -> void:
	var language_model := {"endpoint": CLOSED_ENDPOINT, "model": "any", "api_key": "secret"}
	assert_eq(await _chat.answer(language_model, {"messages": []}, PATIENCE_SECONDS), "")


func test_a_failed_answer_is_reported_unless_it_is_quiet() -> void:
	var language_model := {"endpoint": CLOSED_ENDPOINT, "model": "any", "api_key": ""}
	var reports := []
	_chat.failed.connect(
		func(_endpoint: String, trouble: String, _detail: String) -> void: reports.append(trouble)
	)

	await _chat.answer(language_model, {"messages": []}, PATIENCE_SECONDS, true)
	assert_eq(reports, [], "a quiet one says nothing")
	await _chat.answer(language_model, {"messages": []}, PATIENCE_SECONDS)
	assert_eq(reports.size(), 1)


func test_an_endpoint_that_does_not_answer_in_time_gives_no_answer() -> void:
	assert_gt(_port, 0, "a free port to listen on")
	get_tree().paused = true
	var start := Time.get_ticks_msec()
	var answer: String = await _chat.answer(_language_model(), {"messages": []}, 0.5)
	get_tree().paused = false
	assert_eq(answer, "")
	# Well under the patience a stalled machine is given, but far over the 0.5 s timeout.
	assert_lt(Time.get_ticks_msec() - start, 30000)


func test_the_models_are_the_ids_the_endpoint_lists() -> void:
	var list := '{"object": "list", "data": [{"id": "qwen2.5:3b-instruct"}, {"id": "llama3.2"}]}'
	var ask := func() -> Array[String]:
		return await _chat.models(_language_model("sk-test"), PATIENCE_SECONDS)
	var asked := await _ask_and_answer(ask, _response("200 OK", list))
	assert_string_starts_with(asked[0], "GET /v1/models HTTP/1.1")
	assert_string_contains(asked[0], "Authorization: Bearer sk-test")
	assert_eq(asked[1], ["qwen2.5:3b-instruct", "llama3.2"])


func test_geminis_models_are_listed_by_their_bare_names() -> void:
	var list := '{"object": "list", "data": [{"id": "models/gemini-2.5-flash-lite"}]}'
	var ask := func() -> Array[String]:
		return await _chat.models(_language_model("AIza"), PATIENCE_SECONDS)
	var asked := await _ask_and_answer(ask, _response("200 OK", list))
	assert_eq(asked[1], ["gemini-2.5-flash-lite"])


func test_the_models_of_an_endpoint_that_cannot_be_asked_are_none() -> void:
	var ask := func() -> Array[String]:
		return await _chat.models(_language_model(), PATIENCE_SECONDS)
	assert_eq((await _ask_and_answer(ask, _response("404 Not Found", "{}")))[1], [])
	assert_eq((await _ask_and_answer(ask, _response("200 OK", '{"data": 3}')))[1], [])
	var closed := {"endpoint": CLOSED_ENDPOINT, "model": "any", "api_key": ""}
	assert_eq(await _chat.models(closed, PATIENCE_SECONDS), [])


func test_a_models_list_that_fails_is_warned_of_once() -> void:
	var language_model := _language_model("sk-wrong")
	language_model["endpoint"] += "/%d" % Time.get_ticks_usec()
	var ask := func() -> Array[String]: return await _chat.models(language_model, PATIENCE_SECONDS)
	var denied := _response("401 Unauthorized", '{"error": "key"}')
	await _ask_and_answer(ask, denied)
	await _ask_and_answer(ask, denied)
	assert_push_warning_count(1)


func test_a_temperature_is_one_from_0_to_2_else_the_games_own() -> void:
	var chosen := []
	for set_temperature in ["1.2", "0", "2", "", "warm", "2.5", "-0.1"]:
		chosen.append(ModelChat.temperature_of({"temperature": set_temperature}, 0.5))
	assert_eq(chosen, [1.2, 0.0, 2.0, 0.5, 0.5, 0.5, 0.5])
