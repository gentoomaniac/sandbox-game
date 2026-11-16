class_name FriendshipMarks
extends Control
## The ten marks of a friendship level (design/villagers/relationships.md, "Shown in the game"),
## filled up to the level: the first two cold, the rest warm, the tenth gilded, a mark not reached
## hollow. Small hearts (tools/art/friendship.py, in both art sets), one cell of the strip
## assets/ui/friendship_marks.png per look.

enum Look { EMPTY, COLD, WARM, GILDED }

const MARKS_PATH := "res://assets/ui/friendship_marks.png"
## The size of a mark's cell (the same in both art sets) and the gap between two marks.
const MARK_SIZE := Vector2i(9, 8)
const MARK_GAP := 2
## The marks of the levels up to this one are cold.
const LAST_COLD := 2

## How many marks are filled (the level).
var level := 0:
	set(value):
		level = value
		queue_redraw()

## The picture of the marks in the art set shown, kept while it is drawn.
var _marks: Texture2D = load(ArtSet.path(MARKS_PATH))


func _init() -> void:
	custom_minimum_size = Vector2(
		FriendshipRules.LEVEL_COUNT * (MARK_SIZE.x + MARK_GAP) - MARK_GAP, MARK_SIZE.y
	)
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_to_group(ArtSet.VIEWS)


## The look of the mark of a level (1 to 10) for a friendship at `reached`.
static func look_of(mark: int, reached: int) -> Look:
	if mark > reached:
		return Look.EMPTY
	if mark <= LAST_COLD:
		return Look.COLD
	return Look.GILDED if mark == FriendshipRules.LEVEL_COUNT else Look.WARM


## Called when the art set changes: reloads the marks of the set now shown.
func show_art_set() -> void:
	_marks = load(ArtSet.path(MARKS_PATH))
	queue_redraw()


func _draw() -> void:
	for mark in range(1, FriendshipRules.LEVEL_COUNT + 1):
		var left := (mark - 1) * (MARK_SIZE.x + MARK_GAP)
		var cell := Rect2(Vector2(look_of(mark, level) * MARK_SIZE.x, 0), MARK_SIZE)
		draw_texture_rect_region(_marks, Rect2(Vector2(left, 0), MARK_SIZE), cell)
