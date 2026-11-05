class_name VitalBar
extends Control
## One bar of the vitals HUD: an icon, then a frame filled from the left as far as the value.

const ICON_SIZE := 12
const GAP := 2
const FRAME_TEXTURE := preload("res://assets/ui/bar_frame.png")

var _icon: Texture2D
var _fill: Texture2D
var _fullness := 1.0


func _init(icon: Texture2D, fill: Texture2D) -> void:
	_icon = icon
	_fill = fill
	custom_minimum_size = Vector2(ICON_SIZE + GAP + FRAME_TEXTURE.get_width(), ICON_SIZE)


## `fullness` is 0 (empty) to 1 (full).
func show_value(fullness: float) -> void:
	if not is_equal_approx(fullness, _fullness):
		_fullness = fullness
		queue_redraw()


func _draw() -> void:
	draw_texture(_icon, Vector2.ZERO)
	var frame_at := Vector2(ICON_SIZE + GAP, (ICON_SIZE - FRAME_TEXTURE.get_height()) / 2)
	draw_texture(FRAME_TEXTURE, frame_at)
	var fill_width := roundi(_fill.get_width() * clampf(_fullness, 0.0, 1.0))
	if fill_width > 0:
		var source := Rect2(0, 0, fill_width, _fill.get_height())
		draw_texture_rect_region(_fill, Rect2(frame_at + Vector2.ONE, source.size), source)
