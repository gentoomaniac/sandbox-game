class_name LanguageModelPage
extends VBoxContainer
## The settings of the language model villagers talk through (see NpcDialogue): the profile in
## use, picked from the list and added, copied, renamed or deleted here, which has a provider (an
## OpenAI-compatible chat API, Claude or Gemini), its endpoint, the
## model's name, the most tokens and the temperature of an answer, and how many lines of a chat and
## long-term memories a villager keeps; and the key, if the provider needs one, which is the
## provider's, not the profile's. Each is stored as it is chosen or typed. The test LLM is the
## default; with the endpoint emptied, villagers speak scripted lines. The endpoint is asked which
## models it has, to pick one from a list (the name can be typed too, as the endpoint may not be
## reachable).

signal back_requested

const LABELS := {
	"endpoint": "Endpoint",
	"model": "Model",
	"api_key": "Key (if it needs one)",
	"max_tokens": "Max tokens per answer",
	"temperature": "Temperature",
}
const PROFILE_TIP := (
	"The settings villagers talk with. Add a profile to keep different settings, for a provider"
	+ " you use twice, say Gemini with a pro and with a flash model. The key is not in the"
	+ " profile: it belongs to the provider."
)
const NAME_TIP := "What the profile is called in the list. Every profile has a name of its own."
const PROVIDER_TIP := (
	"OpenAI-compatible: the test LLM of make llm-up, Ollama, LM Studio or a hosted API."
	+ " Claude: Anthropic's API, which needs an API key and costs money."
	+ " Gemini: Google's API, with a key from AI Studio (free within its limits)."
	+ " Choosing another provider gives the profile that provider's endpoint and model."
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
const MEMORIES_TIP := (
	"How many long-term memories a villager keeps. When there are more, the lightest is forgotten,"
	+ " between equal weights the oldest. Every memory is sent with each question, so more of them"
	+ " make the answers slower (and cost more with a hosted model)."
)
const NOTE := "The key is stored as plain text in settings.cfg."
const FIELD_WIDTH := 260

var first_focus: Control

var _settings: GameSettings
var _profiles := OptionButton.new()
var _new_button := Button.new()
var _copy_button := Button.new()
var _delete_button := Button.new()
var _name := LineEdit.new()
var _provider := OptionButton.new()
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
var _memories_label := Label.new()
var _memories_kept := HSlider.new()
## Says why a name typed was not taken; hidden while there is nothing to say.
var _name_note := Label.new()
## What scrolls: everything between the title and the note.
var _rows := VBoxContainer.new()


func _init(settings: GameSettings) -> void:
	_settings = settings
	var title := Label.new()
	title.text = "Language model"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	add_child(ScrollingList.new(_rows))
	var profile_label := Label.new()
	profile_label.text = "Profile"
	TooltipView.set_text(profile_label, PROFILE_TIP)
	profile_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_rows.add_child(profile_label)
	_profiles.item_selected.connect(_on_profile_selected)
	TooltipView.set_text(_profiles, PROFILE_TIP, "setting_language_model_profile")
	_rows.add_child(_profiles)
	_add_profile_buttons()
	_add_name_and_provider()
	for key: String in LABELS:
		var label := Label.new()
		label.text = LABELS[key]
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		_rows.add_child(label)
		_labels[key] = label
		var field := LineEdit.new()
		field.custom_minimum_size.x = FIELD_WIDTH
		field.secret = key == "api_key"
		field.text_changed.connect(
			func(text: String) -> void: _settings.profiles.set_value(key, text)
		)
		if key in ["endpoint", "api_key"]:
			field.text_changed.connect(func(_text: String) -> void: _models_delay.start())
		_rows.add_child(field)
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
	_add_count_slider(
		_history_label,
		_history_lines,
		Vector2i(
			LanguageModelProfiles.MIN_CHAT_HISTORY_LINES,
			LanguageModelProfiles.MAX_CHAT_HISTORY_LINES
		),
		HISTORY_TIP,
		"setting_chat_history_lines",
		_settings.profiles.set_chat_history_lines
	)
	_add_count_slider(
		_memories_label,
		_memories_kept,
		Vector2i(LanguageModelProfiles.MIN_MEMORIES_KEPT, LanguageModelProfiles.MAX_MEMORIES_KEPT),
		MEMORIES_TIP,
		"setting_memories_kept",
		_settings.profiles.set_memories_kept
	)
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
	_name.text = language_model["name"]
	_name_note.visible = false
	for index in _provider.item_count:
		if _provider.get_item_metadata(index) == chosen:
			_provider.select(index)
	var provider: Dictionary = GameSettings.LANGUAGE_MODEL_PROVIDERS[chosen]
	for key: String in _fields:
		_fields[key].text = language_model[key]
		var tip: String = TIPS[key].get(chosen, TIPS[key][provider["protocol"]])
		TooltipView.set_text(_labels[key], tip)
		TooltipView.set_text(_fields[key], tip, "setting_language_model_%s" % key)
	_history_lines.set_value_no_signal(language_model["chat_history_lines"])
	_memories_kept.set_value_no_signal(language_model["memories_kept"])
	_show_counts()
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


func _add_profile_buttons() -> void:
	var row := HBoxContainer.new()
	var buttons := [
		[_new_button, "New", "A profile of the same provider, with its endpoint and model."],
		[_copy_button, "Copy", "A copy of this profile, to change a setting or two."],
		[_delete_button, "Delete", "Removes this profile. The last one stays."],
	]
	for each: Array in buttons:
		var button: Button = each[0]
		button.text = each[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		TooltipView.set_text(button, each[2], "setting_language_model_%s" % each[1].to_lower())
		row.add_child(button)
	_new_button.pressed.connect(_on_new_pressed)
	_copy_button.pressed.connect(_on_copy_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_rows.add_child(row)


func _add_name_and_provider() -> void:
	var name_label := Label.new()
	name_label.text = "Name"
	TooltipView.set_text(name_label, NAME_TIP)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_rows.add_child(name_label)
	_name.custom_minimum_size.x = FIELD_WIDTH
	_name.text_submitted.connect(_rename)
	_name.focus_exited.connect(func() -> void: _rename(_name.text))
	_name.text_changed.connect(func(_text: String) -> void: _name_note.hide())
	TooltipView.set_text(_name, NAME_TIP, "setting_language_model_name")
	_rows.add_child(_name)
	_name_note.visible = false
	_rows.add_child(_name_note)
	var provider_label := Label.new()
	provider_label.text = "Provider"
	TooltipView.set_text(provider_label, PROVIDER_TIP)
	provider_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_rows.add_child(provider_label)
	for provider: String in GameSettings.LANGUAGE_MODEL_PROVIDERS:
		_provider.add_item(GameSettings.LANGUAGE_MODEL_PROVIDERS[provider]["name"])
		_provider.set_item_metadata(_provider.item_count - 1, provider)
	_provider.item_selected.connect(_on_provider_selected)
	TooltipView.set_text(_provider, PROVIDER_TIP, "setting_language_model_provider")
	_rows.add_child(_provider)


## Lists the profiles to pick from, with the one in use selected.
func _list_profiles() -> void:
	_profiles.clear()
	for profile_name in _settings.profiles.names():
		_profiles.add_item(profile_name)
		if profile_name == _settings.profiles.active["name"]:
			_profiles.select(_profiles.item_count - 1)
	_delete_button.disabled = _profiles.item_count == 1


## A row of a label and a slider for a whole number of the profile, from `limits.x` to `limits.y`.
func _add_count_slider(
	label: Label,
	slider: HSlider,
	limits: Vector2i,
	tip: String,
	tip_id: String,
	set_count: Callable
) -> void:
	TooltipView.set_text(label, tip)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	_rows.add_child(label)
	slider.step = 1
	slider.min_value = limits.x
	slider.max_value = limits.y
	slider.value_changed.connect(
		func(count: float) -> void:
			set_count.call(roundi(count))
			_show_counts()
	)
	TooltipView.set_text(slider, tip, tip_id)
	_rows.add_child(slider)


func _show_counts() -> void:
	var active := _settings.profiles.active
	_history_label.text = "Lines a villager keeps: %d" % active["chat_history_lines"]
	_memories_label.text = "Memories a villager keeps: %d" % active["memories_kept"]


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
	_rows.add_child(row)
	_models_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_rows.add_child(_models_note)


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


func _on_new_pressed() -> void:
	_settings.profiles.add(_settings.profiles.active["provider"])
	show_settings()


func _on_copy_pressed() -> void:
	_settings.profiles.copy()
	show_settings()


func _on_delete_pressed() -> void:
	_settings.profiles.delete()
	show_settings()


## Keeps `new_name` for the profile if it can; the field shows the name the profile has. A name
## refused leaves a note that says why, until the name is typed in again or another profile is
## shown. The profile's own name changes nothing (the field gives it back on every focus loss).
func _rename(new_name: String) -> void:
	new_name = new_name.strip_edges()
	if new_name == _settings.profiles.active["name"]:
		_name.text = new_name
		return
	var renamed := _settings.profiles.rename(new_name)
	_name_note.visible = not renamed
	if not renamed:
		_name_note.text = (
			"A profile needs a name."
			if new_name == ""
			else "Another profile is already called %s." % new_name
		)
	_name.text = _settings.profiles.active["name"]
	_list_profiles()


func _on_provider_selected(index: int) -> void:
	_settings.profiles.set_provider(_provider.get_item_metadata(index))
	show_settings()


## The tokens a reply gets when none is set: what the game asks of a provider of `protocol`.
static func _game_max_tokens(protocol: String) -> int:
	var rules := NpcTalkRules.default_rules()
	return rules.value("claude" if protocol == "claude" else "request", "max_tokens")
