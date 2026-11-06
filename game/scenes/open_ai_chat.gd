class_name OpenAiChat
extends ModelChat
## Asks a language model through an OpenAI-compatible chat API, as Ollama (`make llm-up`),
## LM Studio, llama.cpp's server and most hosted models offer it: one POST to
## <endpoint>/chat/completions, the whole answer at once. Claude's own API has another shape:
## see ClaudeChat.

const PATH := "/chat/completions"


## The address to post to for an endpoint such as "http://127.0.0.1:11434/v1", which may also
## be given with a slash at the end or as the whole address.
static func url_of(endpoint: String) -> String:
	return endpoint if endpoint.ends_with(PATH) else endpoint.trim_suffix("/") + PATH


func _chat_url(endpoint: String) -> String:
	return url_of(endpoint)


func _models_url(endpoint: String) -> String:
	return endpoint.trim_suffix(PATH).trim_suffix("/") + "/models"


func _headers(language_model: Dictionary) -> PackedStringArray:
	var headers := super(language_model)
	if language_model["api_key"] != "":
		headers.append("Authorization: Bearer %s" % language_model["api_key"])
	return headers


func _body(language_model: Dictionary, request: Dictionary) -> Dictionary:
	var body := request.duplicate()
	body["model"] = language_model["model"]
	body["stream"] = false
	return body


func _text_of(answer: Dictionary) -> Variant:
	var choices: Variant = answer.get("choices")
	if choices is Array and not choices.is_empty() and choices[0] is Dictionary:
		var message: Variant = choices[0].get("message")
		if message is Dictionary:
			return message.get("content")
	return null
