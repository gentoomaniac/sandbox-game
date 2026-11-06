class_name FakeChat
extends OpenAiChat
## A language model for tests: it answers every request with the next of `answers` (the last one
## again once they run out) after `seconds`, and keeps the requests it was given.

var answers: Array[String] = ["Aye."]
var seconds := 0.0
var requests: Array[Dictionary] = []


func answer(_language_model: Dictionary, request: Dictionary, _timeout_seconds: float) -> String:
	requests.append(request)
	await get_tree().create_timer(seconds, true).timeout
	return answers.pop_front() if answers.size() > 1 else answers[0]
