class_name QuestVoice
extends RefCounted
## Has a villager say the lines of a quest (see QuestTalk `greet`): as the quest's file has them,
## or, when a model is set and the profile has "Quest lines" on (see NpcDialogue
## `has_model_for`), in the villager's own words, asked quietly: they are typing meanwhile (Npc
## `is_answering`). A model that fails or gives lines that don't fit (see NpcPrompt
## `quest_lines_from_answer`) means the fixed lines are said. The model only words it: the game
## has decided what is said.

var _dialogue: NpcDialogue


func _init(dialogue: NpcDialogue) -> void:
	_dialogue = dialogue


## Says what `saying` holds, to the chat of the villager; the chat of the window is told. A
## coroutine only when the model is asked: else it is done when it returns.
func speak(state: GameState, giver: Npc, saying: QuestTalk.Saying) -> void:
	if saying.lines.is_empty():
		return
	var lines := saying.lines
	if _dialogue.has_model_for(&"quest_lines"):
		giver.is_answering = true
		lines = await _voiced(giver, saying)
		giver.is_answering = false
	QuestTalk.say(state, giver, lines)
	_dialogue.answered.emit(giver)


## The lines in the model's words, or the fixed ones.
func _voiced(giver: Npc, saying: QuestTalk.Saying) -> Array[String]:
	var request := NpcPrompt.quest_lines_request(
		giver, saying.intent, saying.lines, _dialogue.rules, _dialogue.has_full_sheets()
	)
	var answer := await _dialogue.ask(_dialogue.request_at_chat_temperature(request), true)
	var voiced := NpcPrompt.quest_lines_from_answer(
		answer, giver, saying.lines.size(), _dialogue.rules
	)
	if voiced.is_empty():
		return saying.lines
	return voiced
