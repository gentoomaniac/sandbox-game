class_name ModelChat
extends Node
## Asks a language model over HTTP: what OpenAiChat and ClaudeChat share. A subclass says where
## to post, with which headers, what the body is and where the text is in the answer; `answer`
## is the same for both.
##
## It runs while the game is paused, as it is during a chat. A failure is reported as a warning
## and gives no answer; the key is never logged, and never follows a redirect to another host.

## The endpoints found not reachable this session: each is warned of once.
static var _unreachable_warned := {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## The text of the model's answer to `request` ({messages, temperature, max_tokens}, see
## NpcPrompt), asked of the endpoint and model of `language_model` (GameSettings), or "" if
## there is none: the endpoint can't be reached, answers with an error, or not within
## `timeout_seconds`.
func answer(language_model: Dictionary, request: Dictionary, timeout_seconds: float) -> String:
	var url := _chat_url(language_model["endpoint"])
	var body := JSON.stringify(_body(language_model, request))
	var text := await _post(url, _headers(language_model), body, timeout_seconds)
	if text == "":
		return ""
	# Not JSON.parse_string: broken JSON is the endpoint's fault, a warning, not an engine error.
	var json := JSON.new()
	var content: Variant = null
	if json.parse(text) == OK and json.data is Dictionary:
		content = _text_of(json.data)
	if not content is String:
		push_warning("Language model at %s: an answer without text: %s" % [url, text.left(200)])
		return ""
	return content


## The address to post the chat to, for the endpoint of the settings.
func _chat_url(_endpoint: String) -> String:
	assert(false, "a subclass says where to post")
	return ""


## The headers of a request to the endpoint of `language_model`.
func _headers(_language_model: Dictionary) -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json"])


## What to post for `request`, in the shape of this API.
func _body(_language_model: Dictionary, _request: Dictionary) -> Dictionary:
	assert(false, "a subclass says what to post")
	return {}


## The text in the parsed answer of the API, or null if there is none.
func _text_of(_answer: Dictionary) -> Variant:
	assert(false, "a subclass says where the text is")
	return null


## Posts `body` and gives the text of the response, or "" with a warning if it is not a success.
func _post(url: String, headers: PackedStringArray, body: String, timeout: float) -> String:
	var http := HTTPRequest.new()
	http.timeout = timeout
	http.max_redirects = 0
	add_child(http)
	var error := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		http.queue_free()
		push_warning("Language model at %s: can't send (%s)" % [url, error_string(error)])
		return ""
	var response: Array = await http.request_completed
	http.queue_free()
	var result: int = response[0]
	var status: int = response[1]
	var text: String = (response[3] as PackedByteArray).get_string_from_utf8()
	if result in [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE]:
		# Nothing listening there is normal (the default endpoint is the test LLM, which is
		# often not running), so it is said once per endpoint, not for every line.
		if not _unreachable_warned.has(url):
			_unreachable_warned[url] = true
			push_warning(
				"Language model at %s: not reachable; villagers speak scripted lines" % url
			)
		return ""
	if result != HTTPRequest.RESULT_SUCCESS or status != 200:
		push_warning(
			(
				"Language model at %s: no answer (result %d, HTTP %d) %s"
				% [url, result, status, text.left(200)]
			)
		)
		return ""
	return text
