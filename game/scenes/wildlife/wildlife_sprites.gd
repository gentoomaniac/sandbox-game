class_name WildlifeSprites
extends RefCounted
## The pictures of the animals: one sheet per kind (assets/wildlife/<kind>.png, drawn by
## tools/art/animals.py, whose order of actions this mirrors), one row per action and one
## column per frame. Animals face right in the sheets. The farm animals have a sheet per species
## and look, `<species>_<look>`, all with the same actions (drawn by tools/art/livestock.py).

const SHEET_PATH := "res://assets/wildlife/%s.png"
const LIVESTOCK_ACTIONS := {&"idle": 2, &"walk": 4, &"graze": 2, &"sleep": 2}
const COW := {"size": Vector2i(32, 24), "actions": LIVESTOCK_ACTIONS}
const SHEEP := {"size": Vector2i(22, 16), "actions": LIVESTOCK_ACTIONS}
const CHICKEN := {"size": Vector2i(12, 12), "actions": LIVESTOCK_ACTIONS}

## Per kind: the size of a frame and the frames of each action, in the order of the rows.
const SHEETS := {
	&"bird": {"size": Vector2i(8, 8), "actions": {&"idle": 3, &"peck": 2, &"hop": 2, &"fly": 3}},
	&"rabbit": {"size": Vector2i(12, 10), "actions": {&"sit": 2, &"nibble": 2, &"hop": 3}},
	&"squirrel": {"size": Vector2i(14, 12), "actions": {&"sit": 3, &"dart": 3}},
	&"deer":
	{"size": Vector2i(26, 26), "actions": {&"graze": 2, &"look": 2, &"walk": 4, &"bound": 3}},
	&"bee": {"size": Vector2i(4, 4), "actions": {&"hover": 2}},
	&"butterfly":
	{
		"size": Vector2i(6, 6),
		"actions": {&"flutter": 3, &"flutter_pale": 3, &"flutter_pink": 3},
	},
	&"cow_angler": COW,
	&"cow_black_pied": COW,
	&"cow_red_pied": COW,
	&"sheep_white": SHEEP,
	&"sheep_grey": SHEEP,
	&"sheep_black_faced": SHEEP,
	&"chicken_brown": CHICKEN,
	&"chicken_white": CHICKEN,
	&"chicken_rooster": CHICKEN,
}


## A sprite showing a kind's sheet, its feet (the bottom centre of a frame) at its position.
static func make_sprite(kind: StringName) -> Sprite2D:
	var sheet: Dictionary = SHEETS[kind]
	var size: Vector2i = sheet["size"]
	var sprite := Sprite2D.new()
	sprite.texture = load(SHEET_PATH % kind)
	sprite.hframes = max_frames(kind)
	sprite.vframes = sheet["actions"].size()
	sprite.offset = Vector2(0, -size.y / 2.0)
	return sprite


## How many frames the action has.
static func frame_count(kind: StringName, action: StringName) -> int:
	return SHEETS[kind]["actions"][action]


## The sprite frame of a column of an action's row.
static func frame_index(kind: StringName, action: StringName, column: int) -> int:
	var actions: Array = SHEETS[kind]["actions"].keys()
	return actions.find(action) * max_frames(kind) + column


## The most frames any action of a kind has: the width of its sheet in frames.
static func max_frames(kind: StringName) -> int:
	return SHEETS[kind]["actions"].values().max()
