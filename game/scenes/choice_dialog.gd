class_name ChoiceDialog
extends Modal
## A question over the game: a title, a text and a button for each answer. The game stands still
## while it is open. `ask` opens it and `answered` says which button was pressed (by index);
## Escape, or anything else that closes it, answers with the safe choice the asker named.
## Used for what the game must not decide by itself: a save that holds content the game no longer
## has, a save that is refused, and a save that failed before quitting.

signal answered(choice: int)

const PANEL_WIDTH := 360

var _title := Label.new()
var _text := Label.new()
var _buttons := VBoxContainer.new()
var _safe_choice := 0
## The button pressed; -1 while none was.
var _pressed := -1
var _is_leaving := false


func _init() -> void:
	super()
	pauses_game = true
	is_movable = false
	# Over the pause menu, which a quit can come from.
	layer = 20
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.add_child(_title)
	column.add_child(_text)
	column.add_child(_buttons)
	_panel.add_child(column)


## Asks `text` under `title`, with a button for each of `choices`. `safe_choice` is the answer of
## Escape and the button that has the focus, so Enter does the harmless thing. Asking while a
## question is up closes it, which answers the earlier asker with its safe choice.
func ask(title: String, text: String, choices: Array[String], safe_choice: int) -> void:
	close()
	_title.text = title
	_text.text = text
	_safe_choice = safe_choice
	_pressed = -1
	for button in _buttons.get_children():
		_buttons.remove_child(button)
		button.queue_free()
	for index in choices.size():
		var button := Button.new()
		button.text = choices[index]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_choose.bind(index))
		_buttons.add_child(button)
	open()


func _on_open() -> void:
	_buttons.get_child(_safe_choice).grab_focus()


## The window is removed with the game (a quit while it is up): nobody is left to answer.
func _exit_tree() -> void:
	_is_leaving = true
	super()


func _on_close() -> void:
	if _is_leaving:
		return
	answered.emit(_safe_choice if _pressed == -1 else _pressed)


func _choose(index: int) -> void:
	_pressed = index
	close()
