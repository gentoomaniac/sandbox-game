class_name FakeChat
extends ModelChat
## A language model for tests: it answers every request with the next of `answers` (the last one
## again once they run out) after `seconds`, and keeps the requests it was given, and the
## language models (endpoint, key) they were asked of.

var answers: Array[String] = ["Aye."]
var seconds := 0.0
var requests: Array[Dictionary] = []
var language_models: Array[Dictionary] = []


func answer(language_model: Dictionary, request: Dictionary, _timeout_seconds: float) -> String:
	language_models.append(language_model.duplicate())
	requests.append(request)
	await get_tree().create_timer(seconds, true).timeout
	return answers.pop_front() if answers.size() > 1 else answers[0]
