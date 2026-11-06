class_name LanguageModelPage
extends VBoxContainer
## The settings of the language model villagers talk through (see NpcDialogue): the endpoint of
## an OpenAI-compatible chat API, the model's name and a key, if it needs one. Each is stored as
## it is typed. Without an endpoint villagers speak scripted lines.

signal back_requested

const FIELDS := {
	"endpoint": ["Endpoint", "http://127.0.0.1:11434/v1"],
	"model": ["Model", GameSettings.DEFAULT_LANGUAGE_MODEL["model"]],
	"api_key": ["Key (if it needs one)", ""],
}
const TIPS := {
	"endpoint":
	(
		"The address of an OpenAI-compatible chat API, such as the test LLM of make llm-up."
		+ " Empty: villagers speak short scripted lines."
	),
	"model": "The name of the model the endpoint should use.",
	"api_key": "Sent to the endpoint. Kept as plain text in settings.cfg, never in the save.",
}
const NOTE := "The key is stored as plain text in settings.cfg."
const FIELD_WIDTH := 260

var first_focus: Control

var _settings: GameSettings
var _fields := {}


func _init(settings: GameSettings) -> void:
	_settings = settings
	var title := Label.new()
	title.text = "Language model"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	for key: String in FIELDS:
		var label := Label.new()
		label.text = FIELDS[key][0]
		TooltipView.set_text(label, TIPS[key])
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(label)
		var field := LineEdit.new()
		field.placeholder_text = FIELDS[key][1]
		field.custom_minimum_size.x = FIELD_WIDTH
		field.secret = key == "api_key"
		field.text_changed.connect(
			func(text: String) -> void: _settings.set_language_model(key, text)
		)
		TooltipView.set_text(field, TIPS[key], "setting_language_model_%s" % key)
		add_child(field)
		_fields[key] = field
	first_focus = _fields["endpoint"]
	var note := Label.new()
	note.text = NOTE
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(note)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(back_requested.emit)
	add_child(back)


## Brings the fields up to date with the settings.
func show_settings() -> void:
	for key: String in _fields:
		_fields[key].text = _settings.language_model[key]
