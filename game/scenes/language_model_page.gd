class_name LanguageModelPage
extends VBoxContainer
## The settings of the language model villagers talk through (see NpcDialogue): the profile in
## use, which has a provider (an OpenAI-compatible chat API, Claude or Gemini), its endpoint, the
## model's name, the most tokens and the temperature of an answer, and how many lines of a chat a
## villager keeps; and the key, if the provider needs one, which is the provider's, not the
## profile's. Each is stored as it is chosen or typed. The test LLM is the default; with the
## endpoint emptied, villagers speak scripted lines. The endpoint is asked which models it has,
## to pick one from a list (the name can be typed too, as the endpoint may not be reachable).

signal back_requested

const LABELS := {
	"endpoint": "Endpoint",
	"model": "Model",
	"api_key": "Key (if it needs one)",
	"max_tokens": "Max tokens per answer",
	"temperature": "Temperature",
}
const PROFILE_TIP := (
	"The settings villagers talk with. By default a profile for each provider: OpenAI-compatible"
	+ " (the test LLM of make llm-up, Ollama, LM Studio or a hosted API), Claude (Anthropic's"
	+ " API, which needs an API key and costs money) and Gemini (Google's API, with a key from"
	+ " AI Studio, free within its limits)."
)
## What each field is for, by the provider, else by its protocol.
const TIPS := {
	"endpoint":
	{
		"openai":
		(
			"The address of the chat API. By default the test LLM of make llm-up."
			+ " Empty: villagers speak short scripted lines."
		),
		"claude": "The address of Anthropic's API. Empty: villagers speak short scripted lines.",
		"gemini":
		(
			"The address of Gemini's OpenAI-compatible API. Empty: villagers speak short"
			+ " scripted lines."
		),
	},
	"model":
	{
		"openai": "The name of the model the endpoint should use.",
		"claude": "The Claude model: claude-opus-5-5, or the much cheaper claude-haiku-5-5.",
		"gemini":
		(
			"The Gemini model. A Flash-Lite model answers fastest; a model that thinks first"
			+ " may use up a line's few tokens and say nothing."
		),
	},
	"max_tokens":
	{
		"openai":
		(
			"The most tokens a villager's line or memory may take. Empty: the game's own. A model"
			+ " that thinks first counts its thinking too, so give it a few hundred or more."
		),
		"claude":
		(
			"The most tokens a villager's line or memory may take, thinking included. Empty: the"
			+ " game's own."
		),
	},
	"temperature":
	{
		"openai":
		(
			"How freely a villager's line varies, 0 to 2: lower is steadier, higher more surprising."
			+ " Empty: the game's own."
		),
		"claude": "Claude's API takes no temperature, so this has no effect.",
	},
	"api_key":
	{
		"openai":
		(
			'Sent to the endpoint as "Authorization: Bearer <key>". Kept as plain text in'
			+ " settings.cfg, never in the save."
		),
		"claude":
		(
			'Your Anthropic API key, sent to Anthropic as "x-api-key". Kept as plain text in'
			+ " settings.cfg, never in the save."
		),
		"gemini":
		(
			"Your Gemini API key from aistudio.google.com/apikey, sent to Google as"
			+ ' "Authorization: Bearer <key>". Kept as plain text in settings.cfg, never in the'
			+ " save."
		),
	},
}
const HISTORY_TIP := (
	"How many of the latest chat lines a villager keeps and tells the model. Older lines are"
	+ " summed up in the villager's memory. Every kept line is sent with each question, so more"
	+ " lines make the answers slower (and cost more with a hosted model)."
)
const NOTE := "The key is stored as plain text in settings.cfg."
const FIELD_WIDTH := 260

var first_focus: Control

var _settings: GameSettings
var _profiles := OptionButton.new()
var _labels := {}
var _fields := {}
## Ask for the models, one for each protocol of the providers.
var _chats := {"openai": OpenAiChat.new(), "claude": ClaudeChat.new()}
var _models := OptionButton.new()
var _models_note := Label.new()
## Asks for the models once the endpoint or key has not been typed in for a moment.
var _models_delay := Timer.new()
var _models_asked := 0
## Seconds to wait for the list of models before giving up on the endpoint.
var _models_timeout: float = NpcTalkRules.default_rules().value("request", "models_timeout_seconds")
var _history_label := Label.new()
var _history_lines := HSlider.new()


func _init(settings: GameSettings) -> void:
	_settings = settings
	var title := Label.new()
	title.text = "Language model"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var profile_label := Label.new()
	profile_label.text = "Profile"
	TooltipView.set_text(profile_label, PROFILE_TIP)
	profile_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(profile_label)
	_profiles.item_selected.connect(_on_profile_selected)
	TooltipView.set_text(_profiles, PROFILE_TIP, "setting_language_model_profile")
	add_child(_profiles)
	for key: String in LABELS:
		var label := Label.new()
		label.text = LABELS[key]
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(label)
		_labels[key] = label
		var field := LineEdit.new()
		field.custom_minimum_size.x = FIELD_WIDTH
		field.secret = key == "api_key"
		field.text_changed.connect(
			func(text: String) -> void: _settings.profiles.set_value(key, text)
		)
		if key in ["endpoint", "api_key"]:
			field.text_changed.connect(func(_text: String) -> void: _models_delay.start())
		add_child(field)
		_fields[key] = field
		if key == "model":
			_add_model_list()
	first_focus = _profiles
	for chat: ModelChat in _chats.values():
		add_child(chat)
	_models_delay.one_shot = true
	_models_delay.wait_time = NpcTalkRules.default_rules().value("request", "models_delay_seconds")
	_models_delay.timeout.connect(show_models)
	add_child(_models_delay)
	TooltipView.set_text(_history_label, HISTORY_TIP)
	_history_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_history_label)
	_history_lines.step = 1
	_history_lines.min_value = LanguageModelProfiles.MIN_CHAT_HISTORY_LINES
	_history_lines.max_value = LanguageModelProfiles.MAX_CHAT_HISTORY_LINES
	_history_lines.value_changed.connect(
		func(lines: float) -> void:
			_settings.profiles.set_chat_history_lines(roundi(lines))
			_show_history_lines()
	)
	TooltipView.set_text(_history_lines, HISTORY_TIP, "setting_chat_history_lines")
	add_child(_history_lines)
	var note := Label.new()
	note.text = NOTE
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(note)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(back_requested.emit)
	add_child(back)


## Brings the fields up to date with the settings: the profile in use, with the placeholders and
## tips of its provider.
func show_settings() -> void:
	var language_model := _settings.profiles.language_model()
	var chosen: String = language_model["provider"]
	_list_profiles()
	var provider: Dictionary = GameSettings.LANGUAGE_MODEL_PROVIDERS[chosen]
	for key: String in _fields:
		_fields[key].text = language_model[key]
		var tip: String = TIPS[key].get(chosen, TIPS[key][provider["protocol"]])
		TooltipView.set_text(_labels[key], tip)
		TooltipView.set_text(_fields[key], tip, "setting_language_model_%s" % key)
	_history_lines.set_value_no_signal(language_model["chat_history_lines"])
	_show_history_lines()
	_fields["endpoint"].placeholder_text = provider["endpoint"]
	_fields["model"].placeholder_text = provider["model"]
	_fields["max_tokens"].placeholder_text = str(_game_max_tokens(provider["protocol"]))
	_fields["temperature"].placeholder_text = str(
		NpcTalkRules.default_rules().value("request", "temperature")
	)
	show_models()


## Asks the endpoint for its models and lists them. Without an answer the saved model is all
## there is to pick, and a note says so.
func show_models() -> void:
	_models_asked += 1
	var asked := _models_asked
	var language_model := _settings.profiles.language_model()
	var provider: Dictionary = GameSettings.LANGUAGE_MODEL_PROVIDERS[language_model["provider"]]
	if language_model["endpoint"] == "":
		_list_models([], "No endpoint: villagers speak scripted lines.")
		return
	if provider["needs_key"] and language_model["api_key"] == "":
		_list_models([], "Enter the key to list the models.")
		return
	_models_note.text = "Asking for the models..."
	var names: Array[String] = await _chats[provider["protocol"]].models(
		language_model, _models_timeout
	)
	if asked != _models_asked:
		return
	_list_models(
		names, "The endpoint did not list its models: type the name." if names.is_empty() else ""
	)


## Lists the profiles to pick from, with the one in use selected.
func _list_profiles() -> void:
	_profiles.clear()
	for profile_name in _settings.profiles.names():
		_profiles.add_item(profile_name)
		if profile_name == _settings.profiles.active["name"]:
			_profiles.select(_profiles.item_count - 1)


func _show_history_lines() -> void:
	_history_label.text = (
		"Lines a villager keeps: %d" % _settings.profiles.active["chat_history_lines"]
	)


func _add_model_list() -> void:
	var row := HBoxContainer.new()
	_models.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_models.item_selected.connect(_on_model_picked)
	TooltipView.set_text(_models, "The models the endpoint offers.", "setting_language_model_list")
	row.add_child(_models)
	var refresh := Button.new()
	refresh.text = "Refresh"
	refresh.pressed.connect(show_models)
	row.add_child(refresh)
	add_child(row)
	_models_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_models_note)


## Lists `names` to pick from, with the saved model among them, and `note` below.
func _list_models(names: Array[String], note: String) -> void:
	var saved: String = _settings.profiles.active["model"]
	_models.clear()
	if saved != "" and not saved in names:
		_models.add_item(saved)
	for name in names:
		_models.add_item(name)
	for index in _models.item_count:
		if _models.get_item_text(index) == saved:
			_models.select(index)
	_models_note.text = note


func _on_model_picked(index: int) -> void:
	var model := _models.get_item_text(index)
	_settings.profiles.set_value("model", model)
	_fields["model"].text = model


func _on_profile_selected(index: int) -> void:
	_settings.profiles.select(_profiles.get_item_text(index))
	show_settings()


## The tokens a reply gets when none is set: what the game asks of a provider of `protocol`.
static func _game_max_tokens(protocol: String) -> int:
	var rules := NpcTalkRules.default_rules()
	return rules.value("claude" if protocol == "claude" else "request", "max_tokens")
