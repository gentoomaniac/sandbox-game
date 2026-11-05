class_name HarvestHud
extends CanvasLayer
## Shows "+1 turnip" briefly after a harvest, with the running count under the clock.

const MESSAGE_SECONDS := 1.5

var _label := Label.new()
var _tween: Tween


func _init() -> void:
	# Same look as the clock, one line below it.
	_label.position = Vector2(4, 12)
	_label.add_theme_color_override("font_color", Color("f1e6c2"))
	_label.add_theme_color_override("font_outline_color", Color(0.161, 0.153, 0.2))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_font_size_override("font_size", 8)
	add_child(_label)


func show_harvest(crop_name: String, total: int) -> void:
	_label.text = "+1 %s (%d harvested)" % [crop_name, total]
	_label.modulate.a = 1.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(MESSAGE_SECONDS)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.5)
