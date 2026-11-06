extends CannedHttpTest
## ClaudeChat, the client of Anthropic's Messages API: the request it sends (headers, system
## line on top, no temperature, fallbacks only for the models that take them) and what it makes
## of the answers of a small server here. A real Claude is asked only with ANTHROPIC_API_KEY
## set.

const REPLY_BODY := (
	'{"content": [{"type": "thinking", "thinking": "hm"}, {"type": "text", "text": "Aye, "},'
	+ ' {"type": "text", "text": "it held."}], "stop_reason": "end_turn"}'
)
const REQUEST := {
	"temperature": 0.7,
	"max_tokens": 60,
	"messages":
	[
		{"role": "system", "content": "You are a villager."},
		{"role": "user", "content": "Hello?"},
		{"role": "assistant", "content": "Aye."},
		{"role": "user", "content": "The dyke?"},
	],
}

var _chat: ClaudeChat


func before_each() -> void:
	super()
	_chat = ClaudeChat.new()
	add_child_autoqfree(_chat)


func _language_model(model := "claude-haiku-5-5") -> Dictionary:
	return {"endpoint": "http://127.0.0.1:%d/v1" % _port, "model": model, "api_key": "sk-ant-test"}


## Asks the chat, answers its request with `response` and gives [the request as text, the
## chat's answer].
func _ask_chat(response: String, model := "claude-haiku-5-5") -> Array:
	var ask := func() -> String: return await _chat.answer(_language_model(model), REQUEST, 5.0)
	return await _ask_and_answer(ask, response)


func test_the_text_blocks_are_the_answer_and_the_thinking_is_left_out() -> void:
	var asked := await _ask_chat(_response("200 OK", REPLY_BODY))
	assert_eq(asked[1], "Aye, it held.")


func test_the_request_has_the_key_and_version_and_the_system_line_on_top() -> void:
	var request: String = (await _ask_chat(_response("200 OK", REPLY_BODY)))[0]
	assert_string_starts_with(request, "POST /v1/messages HTTP/1.1")
	assert_string_contains(request, "x-api-key: sk-ant-test")
	assert_string_contains(request, "anthropic-version: 2026-10-21")
	var body: Dictionary = _body_of(request)
	assert_eq(body["model"], "claude-haiku-5-5")
	assert_eq(body["system"], "You are a villager.")
	assert_eq(body["messages"], REQUEST["messages"].slice(1))
	assert_eq(int(body["max_tokens"]), 1000)
	assert_eq(body["output_config"], {"effort": "low"})
	assert_false(body.has("temperature"))


func test_turns_of_one_role_in_a_row_are_joined_and_the_first_turn_is_the_players() -> void:
	var request := {
		"messages":
		[
			{"role": "system", "content": "You are a villager."},
			{"role": "assistant", "content": "Aye."},
			{"role": "assistant", "content": "Hm."},
			{"role": "user", "content": "Hello?"},
			{"role": "user", "content": "Anyone there?"},
			{"role": "assistant", "content": "Aye."},
			{"role": "user", "content": "The dyke?"},
		],
	}
	var ask := func() -> String: return await _chat.answer(_language_model(), request, 5.0)
	var sent := await _ask_and_answer(ask, _response("200 OK", REPLY_BODY))
	assert_eq(
		_body_of(sent[0])["messages"],
		[
			{"role": "user", "content": "Hello?\nAnyone there?"},
			{"role": "assistant", "content": "Aye."},
			{"role": "user", "content": "The dyke?"},
		]
	)


func test_a_model_without_fallbacks_is_not_asked_for_them() -> void:
	var request: String = (await _ask_chat(_response("200 OK", REPLY_BODY)))[0]
	assert_false(request.contains("anthropic-beta"))
	assert_false(_body_of(request).has("fallbacks"))


func test_a_model_with_fallbacks_is_asked_for_them() -> void:
	var request: String = (await _ask_chat(_response("200 OK", REPLY_BODY), "claude-opus-5-5"))[0]
	assert_string_contains(request, "anthropic-beta: server-side-fallback-2026-07-01")
	assert_eq(_body_of(request)["fallbacks"], "default")


func test_a_refusal_gives_no_answer() -> void:
	var refusal := '{"content": [], "stop_reason": "refusal"}'
	assert_eq((await _ask_chat(_response("200 OK", refusal)))[1], "")
	assert_push_warning_count(1)


func test_an_error_gives_no_answer() -> void:
	var error := '{"type": "error", "error": {"type": "authentication_error", "message": "x"}}'
	assert_eq((await _ask_chat(_response("401 Unauthorized", error)))[1], "")
	assert_push_warning_count(1)


func test_a_redirect_is_not_followed_so_the_key_stays_here() -> void:
	var redirect := (
		"HTTP/1.1 302 Found\r\nLocation: http://example.com/v1/messages\r\n"
		+ "Content-Length: 0\r\nConnection: close\r\n\r\n"
	)
	assert_eq((await _ask_chat(redirect))[1], "")


func test_an_endpoint_that_cannot_be_reached_gives_no_answer() -> void:
	var language_model := {"endpoint": CLOSED_ENDPOINT, "model": "any", "api_key": "secret"}
	assert_eq(await _chat.answer(language_model, REQUEST, 5.0), "")


func test_a_real_claude_answers() -> void:
	var key := OS.get_environment("ANTHROPIC_API_KEY")
	if key == "":
		pass_test("ANTHROPIC_API_KEY is not set: no real Claude to ask")
		return
	var language_model := {
		"endpoint": "https://api.anthropic.com/v1", "model": "claude-haiku-5-5", "api_key": key
	}
	var answer: String = await _chat.answer(language_model, REQUEST, 30.0)
	gut.p("Claude: %s" % answer)
	assert_ne(answer, "")
