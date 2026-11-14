class_name CoordinatesHud
extends CanvasLayer
## The player's tile coordinates in the top right corner, under the energy and health bars, for
## finding places again (and for the console's `tp`). Off by default; the `toggle_coordinates`
## action shows and hides it.
## Inside a house the coordinates are the room's, marked as such. Below them: the weather, and
## when the sun rises and sets. At the bottom: the frames per second the game draws now, to check
## the frame rate limit (Game settings) and spot slow places. Above them the path of the villager
## nearest the player that is on a trip (see NpcTravel `text_of`).

const THEME := preload("res://game/scenes/ui_theme.tres")

var _label := Label.new()


func _init() -> void:
	visible = false
	_label.theme = THEME
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_right = -4
	_label.offset_top = VitalsHud.BOTTOM + 2
	add_child(_label)


func toggle() -> void:
	visible = not visible


## Call every frame; only touches the label when the text changes.
func show_position(tile: Vector2i, is_inside: bool, weather_text: String, path_text := "") -> void:
	if not visible:
		return
	var fps := roundi(Engine.get_frames_per_second())
	var text := text_of(tile, is_inside, weather_text, fps, path_text)
	if _label.text != text:
		_label.text = text


static func text_of(
	tile: Vector2i, is_inside: bool, weather_text: String, fps: int, path_text := ""
) -> String:
	var text := "%s%d, %d\n%s" % ["House " if is_inside else "", tile.x, tile.y, weather_text]
	if path_text != "":
		text += "\n" + path_text
	return text + "\n%d fps" % fps
