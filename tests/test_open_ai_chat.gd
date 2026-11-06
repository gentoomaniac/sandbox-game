extends GutTest
## OpenAiChat, the client of an OpenAI-compatible chat API: the address it posts to, the request
## it sends, and what it makes of the answers of a small server here that answers as told (a
## reply, an error, broken JSON, a redirect, nothing), or of no server at all.

## Nothing listens here, so a request is refused at once.
const CLOSED_ENDPOINT := "http://127.0.0.1:9/v1"
## Waiting for the request gives up after this many frames.
const MAX_FRAMES := 600
const REPLY_BODY := '{"choices": [{"message": {"role": "assistant", "content": "Aye, it held."}}]}'

var _server: TCPServer
var _port := 0
var _chat: OpenAiChat
## The server's end of the connection the chat opened.
var _peer: StreamPeerTCP


func before_each() -> void:
	_server = TCPServer.new()
	for candidate in range(47100, 47200):
		if _server.listen(candidate, "127.0.0.1") == OK:
			_port = candidate
			break
	_chat = OpenAiChat.new()
	add_child_autoqfree(_chat)


func after_each() -> void:
	_server.stop()


func _language_model(api_key := "") -> Dictionary:
	return {"endpoint": "http://127.0.0.1:%d/v1" % _port, "model": "qwen", "api_key": api_key}


## An HTTP response with that status line and body.
static func _response(status: String, body: String) -> String:
	return (
		(
			"HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\n"
			% [status, body.to_utf8_buffer().size()]
		)
		+ "Connection: close\r\n\r\n"
		+ body
	)


## Asks the chat, answers its request with `response` and gives [the request as text, the
## chat's answer].
func _ask_and_answer(response: String, api_key := "") -> Array:
	_peer = null
	var answers := []
	var ask := func() -> void:
		answers.append(await _chat.answer(_language_model(api_key), {"messages": []}, 5.0))
	ask.call()
	var request := await _received_request()
	if request != "":
		_peer.put_data(response.to_utf8_buffer())
		_peer.disconnect_from_host()
	await wait_until(func() -> bool: return not answers.is_empty(), 5.0)
	return [request, answers[0] if not answers.is_empty() else null]


## The whole request the chat sent, headers and body, or "" if none came.
func _received_request() -> String:
	var received := PackedByteArray()
	for _frame in MAX_FRAMES:
		if _peer == null and _server.is_connection_available():
			_peer = _server.take_connection()
		if _peer != null:
			_peer.poll()
			var available := _peer.get_available_bytes()
			if available > 0:
				received.append_array(_peer.get_data(available)[1])
			var text := received.get_string_from_utf8()
			var head_end := text.find("\r\n\r\n")
			var length := RegEx.create_from_string("(?i)content-length: *(\\d+)").search(text)
			if head_end >= 0 and length != null:
				if text.length() - head_end - 4 >= int(length.get_string(1)):
					return text
		await get_tree().process_frame
	return ""


func test_the_address_is_the_endpoint_with_the_chat_path() -> void:
	var expected := "http://127.0.0.1:11434/v1/chat/completions"
	assert_eq(OpenAiChat.url_of("http://127.0.0.1:11434/v1"), expected)
	assert_eq(OpenAiChat.url_of("http://127.0.0.1:11434/v1/"), expected)
	assert_eq(OpenAiChat.url_of(expected), expected)
	assert_eq(OpenAiChat.url_of("http://localhost:1234"), "http://localhost:1234/chat/completions")


func test_an_answer_is_the_text_of_its_first_choice() -> void:
	var asked := await _ask_and_answer(_response("200 OK", REPLY_BODY), "sk-test")
	var request: String = asked[0]
	assert_eq(asked[1], "Aye, it held.")
	assert_string_starts_with(request, "POST /v1/chat/completions HTTP/1.1")
	assert_string_contains(request, "Authorization: Bearer sk-test")
	var body: Dictionary = JSON.parse_string(request.substr(request.find("\r\n\r\n") + 4))
	assert_eq(body["model"], "qwen")
	assert_eq(body["stream"], false)
	assert_eq(body["messages"], [])


func test_without_a_key_no_authorization_is_sent() -> void:
	var asked := await _ask_and_answer(_response("200 OK", REPLY_BODY))
	assert_false(asked[0].contains("Authorization"))


func test_an_error_status_gives_no_answer() -> void:
	var asked := await _ask_and_answer(_response("500 Internal Server Error", '{"error": "x"}'))
	assert_eq(asked[1], "")


func test_broken_json_gives_no_answer() -> void:
	assert_eq((await _ask_and_answer(_response("200 OK", "{choices: ")))[1], "")
	assert_eq((await _ask_and_answer(_response("200 OK", '{"choices": []}')))[1], "")


func test_a_redirect_is_not_followed_so_the_key_stays_here() -> void:
	var redirect := (
		"HTTP/1.1 302 Found\r\nLocation: http://example.com/v1/chat/completions\r\n"
		+ "Content-Length: 0\r\nConnection: close\r\n\r\n"
	)
	assert_eq((await _ask_and_answer(redirect, "sk-test"))[1], "")


func test_an_endpoint_that_cannot_be_reached_gives_no_answer() -> void:
	var language_model := {"endpoint": CLOSED_ENDPOINT, "model": "any", "api_key": "secret"}
	assert_eq(await _chat.answer(language_model, {"messages": []}, 5.0), "")


func test_an_endpoint_that_does_not_answer_in_time_gives_no_answer() -> void:
	assert_gt(_port, 0, "a free port to listen on")
	get_tree().paused = true
	var start := Time.get_ticks_msec()
	var answer: String = await _chat.answer(_language_model(), {"messages": []}, 0.5)
	get_tree().paused = false
	assert_eq(answer, "")
	assert_lt(Time.get_ticks_msec() - start, 3000)
