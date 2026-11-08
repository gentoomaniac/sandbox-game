class_name ThoughtBubble
extends Node2D
## A thought bubble over the player's head: a picture in a pixel-art bubble that pops up,
## stays a moment and fades. Its origin is the bubble's bottom centre, to be put above the
## head. It is drawn on the art pixel grid: the pop is whole pixels, the fade is alpha.
##
## The pictures are assets/ui/bubble_<id>.png, made by tools/art/ui.py from BUBBLE_ICONS: to
## add a bubble, add its picture there and run `make assets`, then `show_icon(&"<id>")`.

const PICTURE_PATH := "res://assets/ui/bubble_%s.png"
## How many pixels lower the bubble starts, and how long it takes to rise into place (it moves
## in whole pixels, so it pops rather than glides).
const POP_DROP := 8
const POP_SECONDS := 0.15
## How long the bubble is there from the start, and how much of that it fades out in.
const LIFE_SECONDS := 2.0
const FADE_SECONDS := 0.4

var _picture: Texture2D
var _age := 0.0


## How many pixels below its place the bubble is this long after it appeared.
static func drop_at(age: float) -> int:
	return POP_DROP - int(POP_DROP * clampf(age / POP_SECONDS, 0.0, 1.0))


## How opaque the bubble is this long after it appeared: 0 once it is gone.
static func alpha_at(age: float) -> float:
	return clampf((LIFE_SECONDS - age) / FADE_SECONDS, 0.0, 1.0)


## Shows the bubble with this picture from its start, in place of one that is showing.
func show_icon(id: StringName) -> void:
	_picture = load(ArtSet.path(PICTURE_PATH % id))
	_age = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func _ready() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE_SECONDS:
		visible = false
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var size := _picture.get_size()
	var drop := drop_at(_age)
	var top_left := Vector2(-int(size.x / 2.0), -size.y + drop)
	draw_texture(_picture, top_left, Color(1.0, 1.0, 1.0, alpha_at(_age)))
