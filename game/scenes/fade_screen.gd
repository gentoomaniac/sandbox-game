class_name FadeScreen
extends CanvasLayer
## The black screen between two moments of the game. It fades out and back in around doors and
## sleep, and can show text on the black: a short note for a moment (the new day after
## sleeping), or a message that waits for a key or a click (after passing out).

## A key or a click went on from the message.
signal continued

const FADE_SECONDS := 0.5
const TEXT_FADE_SECONDS := 0.6
const NOTE_SECONDS := 1.2
const TEXT_WIDTH := 320.0
const HINT := "Press any key to go on"
const HINT_COLOR := Color(1, 1, 1, 0.6)
const THEME := preload("res://game/scenes/ui_theme.tres")

var _black := ColorRect.new()
## The text and, under a message, the hint, faded in and out together.
var _lines := VBoxContainer.new()
var _text := Label.new()
var _hint := Label.new()
var _is_waiting := false


func _init() -> void:
	# Over the HUDs and menus' layer 1, as the scene's fade was.
	layer = 2
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_black)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_lines.theme = THEME
	_lines.modulate.a = 0.0
	_lines.add_theme_constant_override("separation", 12)
	centre.add_child(_lines)
	_text.custom_minimum_size.x = TEXT_WIDTH
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lines.add_child(_text)
	_hint.text = HINT
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = HINT_COLOR
	_lines.add_child(_hint)


func fade_out() -> void:
	await _fade(_black, "color:a", 1.0, FADE_SECONDS)


func fade_in() -> void:
	await _fade(_black, "color:a", 0.0, FADE_SECONDS)


func is_black() -> bool:
	return _black.color.a >= 1.0


## Shows `text` on the black for a moment.
func show_note(text: String) -> void:
	_text.text = text
	_hint.hide()
	await _fade(_lines, "modulate:a", 1.0, TEXT_FADE_SECONDS)
	await get_tree().create_timer(NOTE_SECONDS).timeout
	await _fade(_lines, "modulate:a", 0.0, TEXT_FADE_SECONDS)


## Shows `text` on the black until a key or a click (see `continued`). What is pressed while
## the text is still fading in doesn't count, so a key that was being hammered doesn't skip it.
func show_message(text: String) -> void:
	_text.text = text
	_hint.show()
	await _fade(_lines, "modulate:a", 1.0, TEXT_FADE_SECONDS)
	_is_waiting = true
	await continued
	_is_waiting = false
	await _fade(_lines, "modulate:a", 0.0, TEXT_FADE_SECONDS)


func is_waiting_for_key() -> bool:
	return _is_waiting


## Takes every key and click while a message waits, so nothing else (the pause menu, say)
## acts on the one that goes on.
func _input(event: InputEvent) -> void:
	if not _is_waiting:
		return
	var is_key: bool = event is InputEventKey and event.pressed and not event.echo
	if is_key or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		continued.emit()


func _fade(target: Object, property: String, value: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(target, property, value, seconds)
	await tween.finished
