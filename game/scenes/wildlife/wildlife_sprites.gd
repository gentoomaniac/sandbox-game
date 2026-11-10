class_name WildlifeSprites
extends RefCounted
## The pictures of the animals: one sheet per kind (assets/wildlife/<kind>.png, drawn by
## tools/art/animals.py, birds.py and sea_birds.py, whose order of actions this mirrors), one row
## per action and one column per frame. Animals face right in the sheets. The farm animals have a
## sheet per species and look, `<species>_<look>`, all with the same actions (a saddled horse has
## one more, `horse_<look>_saddled`; drawn by tools/art/livestock.py), and a cat's three more for
## hunting. All frame sizes below are the pictures' own pixels, drawn at 32 px per tile.

const SHEET_PATH := "res://assets/wildlife/%s.png"
const LIVESTOCK_ACTIONS := {&"idle": 2, &"walk": 4, &"graze": 2, &"sleep": 2, &"run": 4}
const COW := {"size": Vector2i(72, 54), "actions": LIVESTOCK_ACTIONS}
const SHEEP := {"size": Vector2i(44, 32), "actions": LIVESTOCK_ACTIONS}
const CHICKEN := {"size": Vector2i(24, 24), "actions": LIVESTOCK_ACTIONS}
const RABBIT := {"size": Vector2i(24, 20), "actions": LIVESTOCK_ACTIONS}
const DOG := {"size": Vector2i(48, 36), "actions": LIVESTOCK_ACTIONS}
const CAT := {
	"size": Vector2i(32, 24),
	"actions":
	{
		&"idle": 2,
		&"walk": 4,
		&"graze": 2,
		&"sleep": 2,
		&"run": 4,
		&"crouch": 2,
		&"creep": 4,
		&"pounce": 3,
	},
}
const HORSE := {"size": Vector2i(88, 76), "actions": LIVESTOCK_ACTIONS}

## Per kind: the size of a frame and the frames of each action, in the order of the rows.
const SHEETS := {
	&"bird": {"size": Vector2i(22, 18), "actions": {&"idle": 3, &"peck": 2, &"hop": 2, &"fly": 3}},
	&"rabbit": {"size": Vector2i(26, 22), "actions": {&"sit": 2, &"nibble": 2, &"hop": 3}},
	&"squirrel": {"size": Vector2i(28, 24), "actions": {&"sit": 3, &"dart": 3}},
	&"deer":
	{"size": Vector2i(52, 52), "actions": {&"graze": 2, &"look": 2, &"walk": 4, &"bound": 3}},
	&"bee": {"size": Vector2i(10, 10), "actions": {&"hover": 2}},
	&"butterfly":
	{
		"size": Vector2i(14, 14),
		"actions": {&"flutter": 3, &"flutter_pale": 3, &"flutter_pink": 3},
	},
	&"firefly": {"size": Vector2i(6, 6), "actions": {&"dark": 1, &"glow": 1, &"bright": 1}},
	&"stork":
	{
		"size": Vector2i(64, 52),
		"actions": {&"stand": 2, &"walk": 4, &"strike": 2, &"clatter": 2, &"swallow": 2, &"fly": 3},
	},
	# The stork's nest on a roof, and a young stork over its rim (tools/art/stork_nest.py).
	&"stork_nest": {"size": Vector2i(48, 14), "actions": {&"nest": 1}},
	&"stork_chick":
	{
		"size": Vector2i(40, 34),
		"actions":
		{&"head_small": 1, &"head_half_grown": 1, &"head_grown": 1, &"stand": 2, &"flap": 3},
	},
	&"mouse": {"size": Vector2i(24, 14), "actions": {&"sit": 2, &"scurry": 2}},
	&"frog": {"size": Vector2i(24, 16), "actions": {&"sit": 2, &"hop": 2}},
	&"goose":
	{"size": Vector2i(48, 36), "actions": {&"stand": 2, &"graze": 2, &"walk": 2, &"fly": 3}},
	&"oystercatcher":
	{"size": Vector2i(32, 24), "actions": {&"stand": 2, &"probe": 2, &"walk": 2, &"fly": 3}},
	&"dunlin":
	{"size": Vector2i(22, 16), "actions": {&"stand": 2, &"probe": 2, &"walk": 2, &"fly": 3}},
	&"gull":
	{
		"size": Vector2i(40, 32),
		"actions": {&"stand": 2, &"walk": 2, &"peck": 2, &"swim": 2, &"fly": 3},
	},
	&"tern":
	{
		"size": Vector2i(40, 28),
		"actions": {&"fly": 3, &"hover": 2, &"dive": 2, &"splash": 3, &"fly_with_fish": 3},
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
	&"rabbit_agouti": RABBIT,
	&"rabbit_white": RABBIT,
	&"rabbit_dutch": RABBIT,
	&"dog_collie": DOG,
	&"dog_spitz": DOG,
	&"dog_pointer": DOG,
	&"cat_tabby": CAT,
	&"cat_black": CAT,
	&"cat_ginger": CAT,
	&"horse_bay": HORSE,
	&"horse_black": HORSE,
	&"horse_grey": HORSE,
	&"horse_pony": HORSE,
	&"horse_bay_saddled": HORSE,
	&"horse_black_saddled": HORSE,
	&"horse_grey_saddled": HORSE,
	&"horse_pony_saddled": HORSE,
}


## A sprite showing a kind's sheet, its feet (the bottom centre of a frame) at its position.
static func make_sprite(kind: StringName) -> Sprite2D:
	var sheet: Dictionary = SHEETS[kind]
	var size: Vector2i = sheet["size"]
	var sprite := Sprite2D.new()
	sprite.texture = sheet_texture(kind)
	sprite.hframes = max_frames(kind)
	sprite.vframes = sheet["actions"].size()
	sprite.offset = Vector2(0, -size.y / 2.0)
	return sprite


## The sheet of a kind in the chosen art set (see ArtSet): both sets have the same frames.
static func sheet_texture(kind: StringName) -> Texture2D:
	return load(ArtSet.path(SHEET_PATH % kind))


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
