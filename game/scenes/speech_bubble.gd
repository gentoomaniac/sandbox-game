class_name SpeechBubble
extends CanvasLayer
## The line a villager says over their head (see NpcSpeech): cream plate, ink text and outline,
## with a tail that points down at them. It is UI, the size of the HUD's at any zoom, in the pixel
## font, and is placed over the villager where the camera shows them. It pops up and fades like
## the player's thought bubbles (ThoughtBubble). Its origin is the tip of the tail, a little above
## the villager's name tag.

const THEME := preload("res://game/scenes/ui_theme.tres")
## How wide the text gets before it wraps, in UI pixels.
const MAX_TEXT_WIDTH := 110.0
const PADDING := Vector2i(4, 2)
## The tip of the tail is this many art pixels over the feet: a little over the head, where the
## name tag (NpcNameTag) is; for the few seconds the bubble stays it covers the name.
const ABOVE_FEET := NpcNameTag.ABOVE_FEET + 8
const TAIL_HEIGHT := 3
## How far over the feet the top of a bubble of a few lines reaches, in art pixels: a villager
## speaks only when all of it is in view.
const TOP_ABOVE_FEET := ABOVE_FEET + 40

## Holds the plate and the tail, so that the fade takes both.
var _root := Control.new()
var _plate := PanelContainer.new()
var _label := Label.new()
var _tail := Tail.new()
var _speaker: Npc
var _age := 0.0
var _life_seconds := 0.0


func _init() -> void:
	_plate.theme = THEME
	_plate.add_theme_stylebox_override("panel", _plate_style())
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", UiColors.SPEECH_INK)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_label)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_plate)
	_root.add_child(_tail)
	add_child(_root)
	_root.visible = false


func is_showing() -> bool:
	return _speaker != null


## Whom the bubble is over, null if it shows nothing.
func speaker() -> Npc:
	return _speaker


func text() -> String:
	return _label.text


## Shows `text` over `npc` for `seconds`, in place of a line that is showing.
func show_line(npc: Npc, line: String, seconds: float) -> void:
	_speaker = npc
	_age = 0.0
	_life_seconds = seconds
	_label.text = line
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.custom_minimum_size.x = 0.0
	if _label.get_minimum_size().x > MAX_TEXT_WIDTH:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size.x = MAX_TEXT_WIDTH
	_root.visible = true


func hide_line() -> void:
	_speaker = null
	_root.visible = false


## Lets `delta` seconds pass and puts the bubble over the villager as `world_to_ui` (a Callable
## from art pixels of the world to UI pixels, see CameraController) shows them.
func update(delta: float, world_to_ui: Callable) -> void:
	if _speaker == null:
		return
	_age += delta
	if _age >= _life_seconds:
		hide_line()
		return
	_plate.reset_size()
	var head := _speaker.position * TerrainTileset.TILE_SIZE - Vector2(0, ABOVE_FEET)
	var tip: Vector2 = world_to_ui.call(head)
	_root.position = (tip + Vector2(0, ThoughtBubble.drop_at(_age))).round()
	_root.modulate.a = ThoughtBubble.alpha_at(_age, _life_seconds)
	_plate.position = Vector2(-floorf(_plate.size.x / 2.0), -_plate.size.y - TAIL_HEIGHT + 1.0)
	_tail.position = Vector2(0, -TAIL_HEIGHT)


static func _plate_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiColors.SPEECH_FILL
	style.border_color = UiColors.SPEECH_INK
	style.set_border_width_all(1)
	style.content_margin_left = PADDING.x
	style.content_margin_right = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_bottom = PADDING.y
	return style


## The tail: a small triangle under the plate, outlined in ink, pointing down. Its top row is the
## plate's bottom border, so it opens into the plate.
class Tail:
	extends Control

	func _draw() -> void:
		for row in SpeechBubble.TAIL_HEIGHT + 1:
			var half := SpeechBubble.TAIL_HEIGHT - row
			draw_rect(Rect2(-half - 1, row, 2 * half + 2, 1), UiColors.SPEECH_INK)
			draw_rect(Rect2(-half, row, 2 * half, 1), UiColors.SPEECH_FILL)
