class_name ModelChat
extends Node
## Asks a language model over HTTP: what OpenAiChat and ClaudeChat share. A subclass says where
## to post, with which headers, what the body is and where the text is in the answer, and where to
## ask for the list of models; `answer` and `models` are the same for both.
##
## It runs while the game is paused, as it is during a chat. A failure of `answer` is reported as
## a warning and the `failed` signal (see ModelNotices) and gives no answer; the key is never
## logged, and never follows a redirect to another host.

## An `answer` failed. `trouble` says what went wrong in a few words that follow "language model"
## ("is busy (HTTP 503)"), `detail` is the message of the API's error, or "". `endpoint` is the
## one asked.
signal failed(endpoint: String, trouble: String, detail: String)
## An `answer` came.
signal worked(endpoint: String)

## The most tokens that can be set for an answer.
const MAX_TOKENS := 32000
## The highest temperature that can be set for an answer.
const MAX_TEMPERATURE := 2.0

## What was warned of this session by `_warn_once`: each is said once.
static var _warned := {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## The text of the model's answer to `request` ({messages, temperature, max_tokens}, see
## NpcPrompt), asked of the endpoint and model of `language_model` (GameSettings), or "" if
## there is none: the endpoint can't be reached, answers with an error, or not within
## `timeout_seconds`. A quiet answer (`is_quiet`), one the player did not ask for in a chat (the
## judge of the stories), fails without the `failed` signal: the player is told only of the trouble
## that their talk meets.
func answer(
	language_model: Dictionary, request: Dictionary, timeout_seconds: float, is_quiet := false
) -> String:
	var url := _chat_url(language_model["endpoint"])
	var body := JSON.stringify(_body(language_model, request))
	var response := await _send(
		HTTPClient.METHOD_POST, url, _headers(language_model), body, timeout_seconds
	)
	var endpoint: String = language_model["endpoint"]
	if response.trouble != "":
		_fail(endpoint, response.trouble, response.detail, is_quiet)
		return ""
	# Not JSON.parse_string: broken JSON is the endpoint's fault, a warning, not an engine error.
	var json := JSON.new()
	var content: Variant = null
	if json.parse(response.text) == OK and json.data is Dictionary:
		content = _text_of(json.data)
	if not content is String:
		push_warning(
			"Language model at %s: an answer without text: %s" % [url, response.text.left(200)]
		)
		_fail(endpoint, "gave an answer the game can't read", "", is_quiet)
		return ""
	if content.strip_edges() == "":
		_fail(endpoint, "gave an empty answer", "", is_quiet)
		return ""
	worked.emit(endpoint)
	return content


func _fail(endpoint: String, trouble: String, detail: String, is_quiet: bool) -> void:
	if not is_quiet:
		failed.emit(endpoint, trouble, detail)


## The most tokens an answer may take: the number set in Settings for the provider (a model that
## thinks first needs more, as its thinking counts too), else `fallback`, the game's own number
## for the request. Not a whole number from 1 to MAX_TOKENS is the same as none set.
static func max_tokens_of(language_model: Dictionary, fallback: int) -> int:
	var text: String = language_model.get("max_tokens", "")
	if text.is_valid_int() and int(text) >= 1 and int(text) <= MAX_TOKENS:
		return int(text)
	return fallback


## The temperature of a villager's reply: the number set in Settings for the provider, else
## `fallback`, the game's own. Not a number from 0 to MAX_TEMPERATURE is the same as none set.
static func temperature_of(language_model: Dictionary, fallback: float) -> float:
	var text: String = language_model.get("temperature", "")
	if text.is_valid_float() and float(text) >= 0.0 and float(text) <= MAX_TEMPERATURE:
		return float(text)
	return fallback


## The names of the models the endpoint of `language_model` offers, or none if it can't be asked
## (it is down, wants another key, or answers in another shape).
func models(language_model: Dictionary, timeout_seconds: float) -> Array[String]:
	var url := _models_url(language_model["endpoint"])
	var text := (
		(await _send(HTTPClient.METHOD_GET, url, _headers(language_model), "", timeout_seconds))
		. text
	)
	var names: Array[String] = []
	var json := JSON.new()
	if text != "" and json.parse(text) == OK and json.data is Dictionary:
		for model: Variant in json.data.get("data", []):
			if model is Dictionary and model.get("id") is String:
				# Gemini names its models "models/<name>"; the chat takes the bare name.
				names.append(model["id"].trim_prefix("models/"))
	return names


## The address to post the chat to, for the endpoint of the settings.
func _chat_url(_endpoint: String) -> String:
	assert(false, "a subclass says where to post")
	return ""


## The headers of a request to the endpoint of `language_model`.
func _headers(_language_model: Dictionary) -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json"])


## The address of the list of models, for the endpoint of the settings.
func _models_url(_endpoint: String) -> String:
	assert(false, "a subclass says where the models are")
	return ""


## What to post for `request`, in the shape of this API.
func _body(_language_model: Dictionary, _request: Dictionary) -> Dictionary:
	assert(false, "a subclass says what to post")
	return {}


## The text in the parsed answer of the API, or null if there is none.
func _text_of(_answer: Dictionary) -> Variant:
	assert(false, "a subclass says where the text is")
	return null


## Sends the request and gives what came: the text of the response, or the trouble if it is not
## a success (with a warning).
func _send(
	method: HTTPClient.Method, url: String, headers: PackedStringArray, body: String, timeout: float
) -> Response:
	var response := Response.new()
	var http := HTTPRequest.new()
	http.timeout = timeout
	http.max_redirects = 0
	add_child(http)
	var error := http.request(url, headers, method, body)
	if error != OK:
		http.queue_free()
		push_warning("Language model at %s: can't send (%s)" % [url, error_string(error)])
		response.trouble = "can't be asked"
		return response
	var completed: Array = await http.request_completed
	http.queue_free()
	var result: int = completed[0]
	var status: int = completed[1]
	var text: String = (completed[3] as PackedByteArray).get_string_from_utf8()
	if result in [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE]:
		# Nothing listening there is normal (the default endpoint is the test LLM, which is
		# often not running), so it is said once per endpoint, not for every line.
		_warn_once(url, "Language model at %s: not reachable" % url)
		response.trouble = "is not reachable"
		return response
	if result != HTTPRequest.RESULT_SUCCESS or status != 200:
		var warning := (
			"Language model at %s: no answer (result %d, HTTP %d) %s"
			% [url, result, status, text.left(200)]
		)
		# The list of models is asked for as the endpoint or key is typed, and the page shows a
		# note anyway: a wrong key is said once, not at every pause in typing.
		if method == HTTPClient.METHOD_GET:
			_warn_once("%s %d %d" % [url, result, status], warning)
		else:
			push_warning(warning)
		response.trouble = _trouble_of(result, status)
		response.detail = _error_message_of(text)
		return response
	response.text = text
	return response


## What went wrong with a request that was no success, in the words of `failed`.
static func _trouble_of(result: int, status: int) -> String:
	if result == HTTPRequest.RESULT_TIMEOUT:
		return "gave no answer in time"
	if result != HTTPRequest.RESULT_SUCCESS:
		return "gave no answer (result %d)" % result
	if status in [429, 503]:
		return "is busy (HTTP %d)" % status
	if status in [401, 403]:
		return "refused the key (HTTP %d)" % status
	return "answered with an error (HTTP %d)" % status


## The `error.message` of an API's error response, or "" if it has none. Gemini wraps the error in
## a list.
static func _error_message_of(text: String) -> String:
	var json := JSON.new()
	if json.parse(text) != OK:
		return ""
	var body: Variant = json.data
	if body is Array and not body.is_empty():
		body = body[0]
	if body is Dictionary and body.get("error") is Dictionary:
		var message: Variant = body["error"].get("message")
		if message is String:
			return message.strip_edges()
	return ""


static func _warn_once(key: String, warning: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(warning)


## What `_send` got: the `text` of a success, else what went wrong (see `failed`).
class Response:
	var text := ""
	var trouble := ""
	var detail := ""
