extends ResourceCase
## The answer to a line is committed by the dialogue service, so what happens to the chat window
## meanwhile (freed, moved to another villager) neither strands the villager nor misplaces it.

var _npc: Npc
var _other: Npc
var _dialogue: NpcDialogue
var _screen: ChatScreen


func before_each() -> void:
	super.before_each()
	_npc = Npc.create(5, Vector2(_tile) + Vector2(0.5, 0.5), _state.npcs.rules)
	_other = Npc.create(6, _npc.position + Vector2(1, 0), _state.npcs.rules)
	_state.npcs.add(_npc)
	_state.npcs.add(_other)
	var settings := GameSettings.new("user://test_chat/settings.cfg")
	settings.profiles.active["endpoint"] = "http://fake/v1"
	var chat := FakeChat.new()
	chat.seconds = 0.2
	_dialogue = NpcDialogue.new(settings, chat)
	add_child_autofree(_dialogue)
	_screen = ChatScreen.new()
	_screen.dialogue = _dialogue
	add_child_autofree(_screen)


func after_each() -> void:
	get_tree().paused = false


func test_an_answer_coming_after_the_window_is_freed_is_still_kept() -> void:
	_screen.open_chat(_npc, _state)
	_screen.say("Farewell")
	remove_child(_screen)
	_screen.free()
	assert_true(_npc.is_answering)
	await wait_for_signal(_dialogue.answered, 2.0)
	assert_false(_npc.is_answering)
	assert_eq(_npc.chat_history.size(), 2)


func test_the_answer_of_a_chat_left_for_another_lands_only_in_its_own() -> void:
	_screen.open_chat(_npc, _state)
	_screen.say("One")
	_screen.open_chat(_other, _state)
	await wait_for_signal(_dialogue.answered, 2.0)
	assert_eq(_npc.chat_history.size(), 2, "the first villager's chat has the answer")
	assert_eq(_other.chat_history.size(), 0, "the other one's has nothing")
	assert_eq(_screen._messages.get_child_count(), 0, "and the window shows the other chat")
	_screen.close()
