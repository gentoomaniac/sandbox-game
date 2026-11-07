class_name NpcDialogue
extends Node
## What a villager says back to the player: the one place their words come from. With a language
## model set in Settings (GameSettings `language_model`) it is asked through the chat of its
## provider, with the prompt of NpcPrompt; without one, or when it fails or takes too long, the
## villager says one of the scripted lines of data/npc_talk.cfg instead. Only the words come from
## the model: nothing else in the game changes by what it says.
##
## The villager keeps the latest lines of the chat, and the older ones are summed up in a memory
## (`compact`); later prompts tell both.
##
## `reply` is a coroutine: callers `await` it. It runs while the game is paused, as it is during a
## chat.

## Ask the model, one for each protocol of the providers (GameSettings
## `LANGUAGE_MODEL_PROVIDERS`); tests put fakes in their place.
var chats: Dictionary
var rules := NpcTalkRules.default_rules()
var rng := RandomNumberGenerator.new()
var _settings: GameSettings


func _init(
	settings: GameSettings,
	openai_chat: ModelChat = OpenAiChat.new(),
	claude: ModelChat = ClaudeChat.new()
) -> void:
	_settings = settings
	chats = {"openai": openai_chat, "claude": claude}
	process_mode = Node.PROCESS_MODE_ALWAYS
	for model_chat: ModelChat in chats.values():
		add_child(model_chat)
	rng.randomize()


## Whether a language model is set: else every answer is scripted.
func has_model() -> bool:
	return _settings.language_model["endpoint"] != ""


func _chat_of_provider() -> ModelChat:
	var provider: Dictionary = GameSettings.LANGUAGE_MODEL_PROVIDERS[
		_settings.language_model["provider"]
	]
	return chats[provider["protocol"]]


## The villager's answer to `message`, said after the lines of `history` (the chat so far, as
## Npc `chat_history`, without the message) in the game of `state` as it is now.
func reply(npc: Npc, history: Array[Dictionary], message: String, state: GameState) -> String:
	if has_model():
		var moment := NpcMoment.of(state, npc, rules.value("place", "reach"))
		var request := NpcPrompt.reply_request(npc, history, message, moment, rules)
		var answer: String = await _chat_of_provider().answer(
			_settings.language_model, request, rules.value("request", "timeout_seconds")
		)
		answer = NpcPrompt.trimmed_reply(answer, npc, rules.value("request", "reply_sentences"))
		if answer != "":
			return answer
	# A moment's thought before a scripted line too, also when the model gave nothing.
	await get_tree().create_timer(rules.value("scripted", "thinking_seconds"), true).timeout
	var lines: Array = rules.value("scripted", "replies")
	return lines[rng.randi_range(0, lines.size() - 1)]


## Keeps the villager's chat at the length of the setting (GameSettings `chat_history_lines`) and
## makes a memory of the lines that drop out of it (see Npc `add_memory`): summed up by the
## model, or the start of what the player said without one or when it gives nothing. Lines that
## drop out while a summary is asked for wait for the next one. The lines stay in the villager's
## `uncompacted_lines` until their memory is made, so a save made meanwhile loses none.
func compact(npc: Npc, state: GameState) -> void:
	npc.drop_old_lines(_settings.chat_history_lines)
	if npc.is_compacting:
		return
	npc.is_compacting = true
	while not npc.uncompacted_lines.is_empty():
		var lines := npc.uncompacted_lines.duplicate()
		var summary := ""
		if has_model():
			var request := NpcPrompt.memory_request(npc, lines, rules)
			var answer: String = await _chat_of_provider().answer(
				_settings.language_model, request, rules.value("request", "timeout_seconds")
			)
			summary = NpcPrompt.trimmed_reply(answer, npc, 1)
		# The chat was cleared meanwhile: there is nothing to remember.
		if npc.uncompacted_lines.slice(0, lines.size()) != lines:
			continue
		if summary == "":
			summary = NpcPrompt.plain_memory(lines, rules)
		npc.uncompacted_lines = npc.uncompacted_lines.slice(lines.size())
		npc.add_memory(NpcPrompt.dated_memory(summary, state.clock, rules))
	npc.is_compacting = false


## Compacts the chat of every villager of the game of `state`, such as after loading it or
## lowering the setting.
func compact_all(state: GameState) -> void:
	for npc in state.npcs.all():
		compact(npc, state)
