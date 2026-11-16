class_name WorldObjectSnags
extends RefCounted
## The dead and the half-dead trees of every kind (issue #102), derived from the living tree of
## the kind so its numbers stay in one place: `dead_oak` and `half_dead_oak` are the oak's with
## less wood on them. Merged into WorldObjectTypes `TYPES` (see there for the entries); their
## atlas rows follow the market stall's, the dead trees first and then the half-dead, each in
## the order of KINDS (see tools/art/snags.py).
##
## Felling one leaves the stump of its kind and a trunk with the kind's picture (the types
## `dead_oak_trunk` and so on, see WorldObjectTypes `_with_trunks`) with fewer logs.

## The kinds that have a dead and a half-dead tree, in the order of the art.
const KINDS: Array[StringName] = [
	&"oak", &"beech", &"birch", &"alder", &"willow", &"pine", &"spruce"
]
const DEAD_VARIANTS := 3
const HALF_DEAD_VARIANTS := 2
const DEAD_PREFIX := "dead_"
const HALF_DEAD_PREFIX := "half_dead_"

const _FIRST_ROW := 64
## A half-dead tree keeps its kind's seed, but gives it this share as often as the living tree.
const _HALF_DEAD_SEED_CHANCE_SHARE := 0.5
## What a dead and a half-dead tree have less than the living one: dead wood is brittle, and a
## snag half rotten. They keep at least `_MIN_LOGS` and `_MIN_HP`.
const _DEAD_LOGS_LESS := 2
const _HALF_DEAD_LOGS_LESS := 1
const _DEAD_HP_LESS := 2
const _HALF_DEAD_HP_LESS := 1
const _MIN_LOGS := 1
const _MIN_HP := 2
## The pixels each kind's dead and then half-dead picture rises above its cell's bottom, as the
## art draws them (tests/test_object_atlas.gd checks them). They are not the living tree's: a dead
## oak is about as tall, and a half-dead one taller, its dead top standing out of the crown.
const _SPRITE_HEIGHTS := {
	&"oak": [131, 145],
	&"beech": [147, 148],
	&"birch": [127, 135],
	&"alder": [135, 138],
	&"willow": [119, 119],
	&"pine": [159, 156],
	&"spruce": [138, 138],
}


static func dead_type(kind: StringName) -> StringName:
	return StringName(DEAD_PREFIX + kind)


static func half_dead_type(kind: StringName) -> StringName:
	return StringName(HALF_DEAD_PREFIX + kind)


static func is_snag(type: StringName) -> bool:
	return KINDS.any(func(kind): return type == dead_type(kind) or type == half_dead_type(kind))


## The ids of the snags, each to this class's name, for CatalogTopics to keep topics off them.
static func reserved_ids() -> Dictionary:
	var reserved := {}
	for kind in KINDS:
		reserved[dead_type(kind)] = "WorldObjectSnags"
		reserved[half_dead_type(kind)] = "WorldObjectSnags"
	return reserved


## The types of both snags of each kind, from the `living` types of the kinds.
static func types_from(living: Dictionary) -> Dictionary:
	var types := {}
	for index in KINDS.size():
		var kind := KINDS[index]
		var tree: Dictionary = living[kind]
		var dead := _snag_of(kind, tree, _FIRST_ROW + index, DEAD_VARIANTS)
		dead["hp"] = maxi(tree["hp"] - _DEAD_HP_LESS, _MIN_HP)
		dead["trunk"]["logs"] = maxi(tree["trunk"]["logs"] - _DEAD_LOGS_LESS, _MIN_LOGS)
		dead["sprite_height"] = _SPRITE_HEIGHTS[kind][0]
		types[dead_type(kind)] = dead
		var half_dead := _snag_of(kind, tree, _FIRST_ROW + KINDS.size() + index, HALF_DEAD_VARIANTS)
		half_dead["hp"] = maxi(tree["hp"] - _HALF_DEAD_HP_LESS, _MIN_HP)
		half_dead["trunk"]["logs"] = maxi(tree["trunk"]["logs"] - _HALF_DEAD_LOGS_LESS, _MIN_LOGS)
		half_dead["sprite_height"] = _SPRITE_HEIGHTS[kind][1]
		half_dead["seed"] = tree["seed"]
		half_dead["seed_chance"] = tree["seed_chance"] * _HALF_DEAD_SEED_CHANCE_SHARE
		types[half_dead_type(kind)] = half_dead
	return types


## What a snag of `kind` has as the living `tree` has it; the caller sets what it has less of.
static func _snag_of(
	kind: StringName, tree: Dictionary, atlas_row: int, variants: int
) -> Dictionary:
	return {
		"tool": tree["tool"],
		"trunk": tree["trunk"].duplicate(),
		"leaves": tree["leaves"],
		"regrows": true,
		"regrows_as": kind,
		"footprint": tree["footprint"],
		"blocks_walking": true,
		"harvest_level": tree["harvest_level"],
		"atlas_row": atlas_row,
		"variants": variants,
	}
