class_name HarvestHud
extends CanvasLayer
## Shows a short note under the clock for a moment, such as "+1 turnip" after a harvest.

const MESSAGE_SECONDS := 1.5
const THEME := preload("res://game/scenes/ui_theme.tres")

var _label := Label.new()
var _tween: Tween


func _init() -> void:
	# Same look as the clock, one line below it.
	_label.position = Vector2(4, 12)
	_label.theme = THEME
	add_child(_label)


func show_note(text: String) -> void:
	_label.text = text
	_label.modulate.a = 1.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(MESSAGE_SECONDS)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.5)
