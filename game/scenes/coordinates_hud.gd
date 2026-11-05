class_name CoordinatesHud
extends CanvasLayer
## The player's tile coordinates in the top right corner, for finding places again (and for
## the console's `tp`). Off by default; the `toggle_coordinates` action shows and hides it.
## Inside a house the coordinates are the room's, marked as such.

const THEME := preload("res://game/scenes/ui_theme.tres")

var _label := Label.new()


func _init() -> void:
	visible = false
	_label.theme = THEME
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_right = -4
	_label.offset_top = 2
	add_child(_label)


func toggle() -> void:
	visible = not visible


## Call every frame; only touches the label when the text changes.
func show_position(tile: Vector2i, is_inside: bool) -> void:
	if not visible:
		return
	var text := "%s%d, %d" % ["House " if is_inside else "", tile.x, tile.y]
	if _label.text != text:
		_label.text = text
