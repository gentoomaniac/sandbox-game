class_name ClaudeChat
extends ModelChat
## Asks Claude through Anthropic's Messages API: one POST to <endpoint>/messages. NpcPrompt's
## request is built for OpenAI-style APIs, so its system lines become the top-level `system` and
## the rest stay the user and assistant turns, which Claude wants to alternate and to start with
## the user's: turns of one role in a row are joined, and the villager lines the history starts
## with are left out. Its temperature is left out (current models refuse it) and the numbers of
## [claude] in data/npc_talk.cfg are used instead.

const PATH := "/messages"

var _rules := NpcTalkRules.default_rules()


func _chat_url(endpoint: String) -> String:
	return endpoint.trim_suffix("/") + PATH


func _headers(language_model: Dictionary) -> PackedStringArray:
	var headers := super(language_model)
	headers.append("x-api-key: %s" % language_model["api_key"])
	headers.append("anthropic-version: %s" % _rules.value("claude", "api_version"))
	if _takes_fallbacks(language_model["model"]):
		headers.append("anthropic-beta: %s" % _rules.value("claude", "fallback_beta"))
	return headers


func _body(language_model: Dictionary, request: Dictionary) -> Dictionary:
	var system: Array[String] = []
	var turns := []
	for message: Dictionary in request["messages"]:
		if message["role"] == "system":
			system.append(message["content"])
		elif turns.is_empty() and message["role"] == "assistant":
			continue
		elif not turns.is_empty() and turns[-1]["role"] == message["role"]:
			turns[-1]["content"] += "\n" + message["content"]
		else:
			turns.append(message.duplicate())
	var body := {
		"model": language_model["model"],
		"max_tokens": _rules.value("claude", "max_tokens"),
		"output_config": {"effort": _rules.value("claude", "effort")},
		"messages": turns,
	}
	if not system.is_empty():
		body["system"] = "\n\n".join(system)
	if _takes_fallbacks(language_model["model"]):
		body["fallbacks"] = "default"
	return body


## The text blocks of the answer joined; its thinking is left out. A refusal gives no text.
func _text_of(answer: Dictionary) -> Variant:
	if answer.get("stop_reason") == "refusal":
		push_warning("Claude refused to answer; the villager speaks a scripted line")
		return ""
	var content: Variant = answer.get("content")
	if not content is Array:
		return null
	var text := ""
	for block: Variant in content:
		if block is Dictionary and block.get("type") == "text":
			text += block.get("text", "")
	return text


func _takes_fallbacks(model: String) -> bool:
	return model in _rules.value("claude", "fallback_models")
