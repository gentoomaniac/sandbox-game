class_name NpcDialogue
extends Node
## What a villager says back to the player: the one place their words come from. With a language
## model set in Settings (GameSettings `language_model`) it is asked through `chat`, with the
## prompt of NpcPrompt; without one, or when it fails or takes too long, the villager says one of
## the scripted lines of data/npc_talk.cfg instead. Only the words come from the model: nothing
## else in the game changes by what it says.
##
## When a conversation is over its lines are summed up in a memory of the villager (`remember`),
## which later prompts tell.
##
## `reply` is a coroutine: callers `await` it. It runs while the game is paused, as it is during a
## chat.

## Asks the model; tests put a fake in its place.
var chat: OpenAiChat
var rules := NpcTalkRules.default_rules()
var rng := RandomNumberGenerator.new()
var _settings: GameSettings


func _init(settings: GameSettings, model_chat := OpenAiChat.new()) -> void:
	_settings = settings
	chat = model_chat
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(chat)
	rng.randomize()


## Whether a language model is set: else every answer is scripted.
func has_model() -> bool:
	return _settings.language_model["endpoint"] != ""


## The villager's answer to `message`, said after the lines of `history` (the chat so far, as
## Npc `chat_history`, without the message) in the game of `state` as it is now.
func reply(npc: Npc, history: Array[Dictionary], message: String, state: GameState) -> String:
	if has_model():
		var moment := NpcMoment.of(state, npc, rules.value("place", "reach"))
		var request := NpcPrompt.reply_request(npc, history, message, moment, rules)
		var answer: String = await chat.answer(
			_settings.language_model, request, rules.value("request", "timeout_seconds")
		)
		answer = NpcPrompt.trimmed_reply(answer, npc, rules.value("request", "reply_sentences"))
		if answer != "":
			return answer
	else:
		await get_tree().create_timer(rules.value("scripted", "thinking_seconds"), true).timeout
	var lines: Array = rules.value("scripted", "replies")
	return lines[rng.randi_range(0, lines.size() - 1)]


## Remembers the `lines` of a conversation with the villager (see Npc `add_memory`): summed up by
## the model, or the start of what the player said without one or when it gives nothing.
func remember(npc: Npc, lines: Array[Dictionary], state: GameState) -> void:
	var summary := ""
	if has_model():
		var request := NpcPrompt.memory_request(npc, lines, rules)
		var answer: String = await chat.answer(
			_settings.language_model, request, rules.value("request", "timeout_seconds")
		)
		summary = NpcPrompt.trimmed_reply(answer, npc, 1)
	if summary == "":
		summary = NpcPrompt.plain_memory(lines, rules)
	npc.add_memory(NpcPrompt.dated_memory(summary, state.clock, rules))
