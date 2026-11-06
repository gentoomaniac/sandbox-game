class_name LanguageModelPage
extends VBoxContainer
## The settings of the language model villagers talk through (see NpcDialogue): the provider
## (an OpenAI-compatible chat API, or Claude), its endpoint, the model's name and a key, if it
## needs one. Each provider keeps its own; each is stored as it is chosen or typed. The test LLM
## is the default; with the endpoint emptied, villagers speak scripted lines.

signal back_requested

const LABELS := {"endpoint": "Endpoint", "model": "Model", "api_key": "Key (if it needs one)"}
const PROVIDER_TIP := (
	"OpenAI-compatible: the test LLM of make llm-up, Ollama, LM Studio or a hosted API."
	+ " Claude: Anthropic's API, which needs an API key and costs money."
)
## What each field is for, by the protocol of the provider.
const TIPS := {
	"endpoint":
	{
		"openai":
		(
			"The address of the chat API. By default the test LLM of make llm-up."
			+ " Empty: villagers speak short scripted lines."
		),
		"claude": "The address of Anthropic's API. Empty: villagers speak short scripted lines.",
	},
	"model":
	{
		"openai": "The name of the model the endpoint should use.",
		"claude": "The Claude model: claude-opus-5-5, or the much cheaper claude-haiku-5-5.",
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
	},
}
const NOTE := "The key is stored as plain text in settings.cfg."
const FIELD_WIDTH := 260

var first_focus: Control

var _settings: GameSettings
var _provider := OptionButton.new()
var _labels := {}
var _fields := {}


func _init(settings: GameSettings) -> void:
	_settings = settings
	var title := Label.new()
	title.text = "Language model"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var provider_label := Label.new()
	provider_label.text = "Provider"
	TooltipView.set_text(provider_label, PROVIDER_TIP)
	provider_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(provider_label)
	for provider: String in GameSettings.LANGUAGE_MODEL_PROVIDERS:
		_provider.add_item(GameSettings.LANGUAGE_MODEL_PROVIDERS[provider]["name"])
		_provider.set_item_metadata(_provider.item_count - 1, provider)
	_provider.item_selected.connect(_on_provider_selected)
	TooltipView.set_text(_provider, PROVIDER_TIP, "setting_language_model_provider")
	add_child(_provider)
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
			func(text: String) -> void: _settings.set_language_model(key, text)
		)
		add_child(field)
		_fields[key] = field
	first_focus = _provider
	var note := Label.new()
	note.text = NOTE
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(note)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(back_requested.emit)
	add_child(back)
	show_settings()


## Brings the fields up to date with the settings: the chosen provider's, with its own
## placeholders and tips.
func show_settings() -> void:
	var chosen: String = _settings.language_model["provider"]
	for index in _provider.item_count:
		if _provider.get_item_metadata(index) == chosen:
			_provider.select(index)
	var provider: Dictionary = GameSettings.LANGUAGE_MODEL_PROVIDERS[chosen]
	for key: String in _fields:
		_fields[key].text = _settings.language_model[key]
		var tip: String = TIPS[key][provider["protocol"]]
		TooltipView.set_text(_labels[key], tip)
		TooltipView.set_text(_fields[key], tip, "setting_language_model_%s" % key)
	_fields["endpoint"].placeholder_text = provider["endpoint"]
	_fields["model"].placeholder_text = provider["model"]


func _on_provider_selected(index: int) -> void:
	_settings.set_language_model_provider(_provider.get_item_metadata(index))
	show_settings()
