class_name NotificationHud
extends CanvasLayer
## A few short lines at the top left, below the clock and the harvest note, that fade after a
## moment: "Saving...", "Saved", a failed save in red. A line with a key replaces the line
## that has the same key, so "Saving..." turns into "Saved" in place. It keeps running while the
## game is paused, as a save can end under the pause menu.

enum Tone { PLAIN, ERROR }

const THEME := preload("res://game/scenes/ui_theme.tres")
## Below the harvest note, which is one line under the clock.
const TOP_LEFT := Vector2(4, 24)
const MAX_LINES := 4
const LINE_SECONDS := 2.0
## A failure stays longer: it is the line the player must not miss.
const ERROR_SECONDS := 6.0
const FADE_SECONDS := 0.5
const PADDING := Vector2i(3, 1)

var line_seconds := LINE_SECONDS
var error_seconds := ERROR_SECONDS

var _lines := VBoxContainer.new()
## The line of each key (see `post`).
var _line_of_key: Dictionary[StringName, NotificationLine] = {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lines.position = TOP_LEFT
	_lines.theme = THEME
	_lines.add_theme_constant_override("separation", 1)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)


## Shows `text`, which fades after a few seconds. `key` names what it is about: a later line of
## the same key takes its place. An empty key is never replaced.
func post(key: StringName, text: String, tone := Tone.PLAIN) -> void:
	var line := _show(key, text, tone)
	var seconds := error_seconds if tone == Tone.ERROR else line_seconds
	line.tween = create_tween()
	line.tween.tween_interval(seconds)
	line.tween.tween_property(line, "modulate:a", 0.0, FADE_SECONDS)
	line.tween.tween_callback(_remove.bind(line))


## Shows `text` until a line of the same `key` replaces it or `remove` takes it away.
func hold(key: StringName, text: String) -> void:
	_show(key, text, Tone.PLAIN)


## Takes away the line of `key`, if it is still there.
func remove(key: StringName) -> void:
	if _line_of_key.has(key):
		_remove(_line_of_key[key])


## The lines on show, oldest first.
func texts() -> PackedStringArray:
	var shown := PackedStringArray()
	for line: NotificationLine in _lines.get_children():
		shown.append(line.text)
	return shown


func _show(key: StringName, text: String, tone: Tone) -> NotificationLine:
	var line: NotificationLine = _line_of_key.get(key)
	if line == null:
		if _lines.get_child_count() >= MAX_LINES:
			_remove(_lines.get_child(0))
		line = NotificationLine.new()
		line.key = key
		_lines.add_child(line)
		if key != &"":
			_line_of_key[key] = line
	elif line.tween != null:
		line.tween.kill()
	line.text = text
	line.modulate.a = 1.0
	line.add_theme_stylebox_override("normal", _plate(tone))
	return line


func _remove(line: NotificationLine) -> void:
	if line.tween != null:
		line.tween.kill()
	if line.key != &"":
		_line_of_key.erase(line.key)
	# Out of the box now, as `queue_free` would leave it there for the rest of the frame.
	_lines.remove_child(line)
	line.queue_free()


## The plate behind a line, so it reads over any ground: dim for news, the palette's ember red for
## trouble.
static func _plate(tone: Tone) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.bg_color = UiColors.ERROR_PLATE if tone == Tone.ERROR else UiColors.BACKDROP
	plate.content_margin_left = PADDING.x
	plate.content_margin_right = PADDING.x
	plate.content_margin_top = PADDING.y
	plate.content_margin_bottom = PADDING.y
	return plate


## One line of the HUD, with what it needs to be replaced or taken away.
class NotificationLine:
	extends Label

	var key: StringName
	var tween: Tween
