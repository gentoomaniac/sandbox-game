class_name FriendshipMarks
extends Control
## The ten marks of a friendship level (design/villagers/relationships.md, "Shown in the game"),
## filled up to the level: the first two cold and dark, the rest warm, the tenth gilded.
## PLACEHOLDER: plain squares drawn in code in palette colours; the art of #48 step 14 (a pixel
## artist) is to replace them with a drawn mark, a heart or a knot, in both art sets.

const MARK_SIZE := 8
const MARK_GAP := 2
## Palette colours (see tools/art/palette.py): the cold marks water_deep, the warm ember, the tenth
## gold, and a mark not reached stone_dark.
const COLD_COLOR := Color("2b4561")
const WARM_COLOR := Color("a8402e")
const GILDED_COLOR := Color("eec25a")
const EMPTY_COLOR := Color("4a4852")

## How many marks are filled (the level).
var level := 0:
	set(value):
		level = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(
		FriendshipRules.LEVEL_COUNT * (MARK_SIZE + MARK_GAP) - MARK_GAP, MARK_SIZE
	)
	mouse_filter = Control.MOUSE_FILTER_PASS


## The colour of the mark of a level (1 to 10) for a friendship at `reached`.
static func color_of(mark: int, reached: int) -> Color:
	if mark > reached:
		return EMPTY_COLOR
	if mark <= 2:
		return COLD_COLOR
	return GILDED_COLOR if mark == FriendshipRules.LEVEL_COUNT else WARM_COLOR


func _draw() -> void:
	for mark in range(1, FriendshipRules.LEVEL_COUNT + 1):
		var left := (mark - 1) * (MARK_SIZE + MARK_GAP)
		draw_rect(Rect2(left, 0, MARK_SIZE, MARK_SIZE), color_of(mark, level))
