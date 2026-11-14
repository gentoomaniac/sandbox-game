class_name CoordinatesHud
extends CanvasLayer
## The player's tile coordinates in the top right corner, under the energy and health bars, for
## finding places again (and for the console's `tp`). Off by default; the `toggle_coordinates`
## action shows and hides it.
## Inside a house the coordinates are the room's, marked as such. Below them: the weather, and
## when the sun rises and sets. At the bottom: the frames per second the game draws now, to check
## the frame rate limit (Game settings) and spot slow places.

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
func show_position(tile: Vector2i, is_inside: bool, weather_text: String) -> void:
	if not visible:
		return
	var text := text_of(tile, is_inside, weather_text, roundi(Engine.get_frames_per_second()))
	if _label.text != text:
		_label.text = text


static func text_of(tile: Vector2i, is_inside: bool, weather_text: String, fps: int) -> String:
	return (
		"%s%d, %d\n%s\n%d fps" % ["House " if is_inside else "", tile.x, tile.y, weather_text, fps]
	)


## The weather lines under the coordinates: the values, the snow cover and frost (0 to 1), and
## sunrise and sunset on `day`.
static func weather_and_sun_text(
	weather: WeatherSample, sun: Sun, day: int, snow_cover: float, frost: float
) -> String:
	return (
		"%s\nsnow cover %d %% · frost %d %%\nsunrise %s · sunset %s"
		% [
			weather.short_text(),
			roundi(snow_cover * 100.0),
			roundi(frost * 100.0),
			Sun.time_text(sun.sunrise(day)),
			Sun.time_text(sun.sunset(day)),
		]
	)
