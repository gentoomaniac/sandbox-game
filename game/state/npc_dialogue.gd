class_name NpcDialogue
extends RefCounted
## What a villager says back to the player: the one place their words come from. For now every
## villager answers STUB_REPLY after a moment's thought; later a language model is asked here
## (docs/ideas/NPC.md, TASKS.md 86).
##
## `reply` is a coroutine: callers `await` it, so an answer that takes seconds to come over the
## network fits without changing them.

const STUB_REPLY := "I understand."
## How long the stub thinks before it answers, in real seconds.
const THINKING_SECONDS := 0.5


## The villager's answer to `message`, said after the lines of `history` (the chat so far, as
## Npc `chat_history`, without the message).
static func reply(_npc: Npc, _history: Array[Dictionary], _message: String) -> String:
	# Its timer runs on while the game is paused, as it is during a chat.
	await (Engine.get_main_loop() as SceneTree).create_timer(THINKING_SECONDS, true).timeout
	return STUB_REPLY
