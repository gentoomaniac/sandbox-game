class_name OpenAiChat
extends Node
## Asks a language model through an OpenAI-compatible chat API, as Ollama (`make llm-up`),
## LM Studio, llama.cpp's server and most hosted models offer it: one POST to
## <endpoint>/chat/completions, the whole answer at once. Claude's own API has another shape and
## would need a class of its own with the same `answer`.
##
## It runs while the game is paused, as it is during a chat. A failure is reported as a warning
## and gives no answer; the key is never logged, and never follows a redirect to another host.

const PATH := "/chat/completions"


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## The address to post to for an endpoint such as "http://127.0.0.1:11434/v1", which may also
## be given with a slash at the end or as the whole address.
static func url_of(endpoint: String) -> String:
	return endpoint if endpoint.ends_with(PATH) else endpoint.trim_suffix("/") + PATH


## The text of the model's answer to `request` ({messages, temperature, max_tokens}, see
## NpcPrompt), asked of the endpoint and model of `language_model` (GameSettings), or "" if
## there is none: the endpoint can't be reached, answers with an error, or not within
## `timeout_seconds`.
func answer(language_model: Dictionary, request: Dictionary, timeout_seconds: float) -> String:
	var url := url_of(language_model["endpoint"])
	var headers := PackedStringArray(["Content-Type: application/json"])
	if language_model["api_key"] != "":
		headers.append("Authorization: Bearer %s" % language_model["api_key"])
	var body := request.duplicate()
	body["model"] = language_model["model"]
	body["stream"] = false
	var http := HTTPRequest.new()
	http.timeout = timeout_seconds
	http.max_redirects = 0
	add_child(http)
	var error := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		http.queue_free()
		push_warning("Language model at %s: can't send (%s)" % [url, error_string(error)])
		return ""
	var response: Array = await http.request_completed
	http.queue_free()
	var result: int = response[0]
	var status: int = response[1]
	var text: String = (response[3] as PackedByteArray).get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS or status != 200:
		push_warning(
			(
				"Language model at %s: no answer (result %d, HTTP %d) %s"
				% [url, result, status, text.left(200)]
			)
		)
		return ""
	# Not JSON.parse_string: broken JSON is the endpoint's fault, a warning, not an engine error.
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(text) == OK else null
	var content: Variant = null
	if parsed is Dictionary and parsed.get("choices") is Array and not parsed["choices"].is_empty():
		var choice: Variant = parsed["choices"][0]
		if choice is Dictionary and choice.get("message") is Dictionary:
			content = choice["message"].get("content")
	if not content is String:
		push_warning("Language model at %s: an answer without text: %s" % [url, text.left(200)])
		return ""
	return content
