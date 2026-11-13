class_name NpcSpeech
extends Node
## Has a villager in view say a line in a bubble over their head now and then (see NpcBubbles for
## who, when and what, and design/villagers/gossip.md, Bubbles). The line is asked of the language
## model in the background, quietly like the judge's (see StoryJudging), and shown when it comes,
## unless the villager is out of view by then; without a model it is a scripted one at once. A
## model that fails or gives no usable line means no bubble this time. At most one bubble is on
## screen, and none is asked for while one is. Nothing of it is saved or remembered.

## Debug: a new bubble follows the last at once, not after the wait (see `--bubbles`).
var is_nonstop := false

var _bubbles := NpcBubbles.new()
var _bubble := SpeechBubble.new()
var _state: GameState
var _dialogue: NpcDialogue
var _view_region: Callable
var _world_to_ui: Callable
var _is_asking := false


## Shows the bubbles of the villagers of `state`. `view_region` is a Callable that gives the part
## of the world the camera shows in art pixels, `world_to_ui` one that gives the UI position of a
## point of the world (see CameraController `view_rect` and `world_to_ui`).
func show_for(
	state: GameState, dialogue: NpcDialogue, view_region: Callable, world_to_ui: Callable
) -> void:
	_state = state
	_dialogue = dialogue
	_view_region = view_region
	_world_to_ui = world_to_ui
	add_child(_bubble)


## The line on show, "" if none.
func shown_line() -> String:
	return _bubble.text() if _bubble.is_showing() else ""


func _process(delta: float) -> void:
	# The world stands still indoors, and the camera shows the room.
	if _state.is_inside():
		_bubble.hide_line()
		return
	if _bubble.is_showing():
		_bubble.update(delta, _world_to_ui)
		var speaker := _bubble.speaker()
		if speaker != null and (not _is_in_view(speaker) or speaker.is_answering):
			_bubble.hide_line()
	elif not _is_asking:
		_bubbles.advance(INF if is_nonstop else delta)
		if _bubbles.is_due():
			_speak()


func _speak() -> void:
	var speaker := _bubbles.pick_speaker(
		_state.npcs.all(), _view_region.call(), SpeechBubble.TOP_ABOVE_FEET
	)
	# Still due: the next frame looks again for one in view.
	if speaker == null:
		return
	_bubbles.restart_wait()
	var moment := NpcMoment.of(_state, speaker, _bubbles.rules.value("place", "reach"))
	var subject := _bubbles.subject_for(speaker, _state.player.position)
	var line := ""
	if _dialogue.has_model():
		var request := _bubbles.request(speaker, moment, subject, _dialogue.has_full_sheets())
		_is_asking = true
		var answer := await _dialogue.ask(_dialogue.request_at_chat_temperature(request), true)
		_is_asking = false
		line = _bubbles.line_from_answer(answer, speaker)
	else:
		line = _bubbles.scripted_line(speaker, moment, subject)
	# The villager may have walked off, or begun to talk with the player, while it was asked.
	if line != "" and _is_in_view(speaker) and not speaker.is_answering and not _state.is_inside():
		_bubble.show_line(speaker, line, _bubbles.rules.value("bubble", "show_seconds"))


func _is_in_view(npc: Npc) -> bool:
	return NpcBubbles.is_in_view(npc.position, SpeechBubble.TOP_ABOVE_FEET, _view_region.call())
