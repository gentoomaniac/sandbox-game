class_name WordRating
extends Node
## Has the model rate what the player says to a villager (design/villagers/relationships.md, "Rating
## the player's words"): after an exchange, if a model is set and the profile has "Word rating" on
## (see NpcDialogue `has_model_for`), and the villager has been asked for fewer ratings today than
## the cap allows (TalkFriendship), the line is rated quietly by a request of its own. The rating
## moves the opinion by the game's points, within the caps of the day; an answer that does not come
## in time, or is none of the words, counts as neutral. The model is never asked for a level.

var _dialogue: NpcDialogue
var _state: GameState


func _init(dialogue: NpcDialogue, state: GameState) -> void:
	_dialogue = dialogue
	_state = state
	dialogue.exchanged.connect(_on_exchanged)


func _on_exchanged(npc: Npc, line: String) -> void:
	if not _dialogue.has_model_for(&"word_rating"):
		return
	if not TalkFriendship.take_rating_request(_state, npc):
		return
	var rules := _dialogue.rules
	var request := NpcPrompt.word_rating_request(line, rules)
	var timeout: float = rules.value("word_rating", "timeout_seconds")
	var answer := await _dialogue.ask(request, true, timeout)
	TalkFriendship.apply_rating(_state, npc, NpcPrompt.word_rating_from_answer(answer, rules))
