class_name WorldObjectDyke
extends RefCounted
## The dyke as data, merged into WorldObjectTypes `TYPES` (see there for the entries): a turfed
## bank of clay along the water, drawn by tools/art/boundaries.py in a look per height (see
## DykeProfile `look`), each look a row of the atlas.

const _DYKE_ROW := 30
const _DYKE_LOW_ROW := 80
const _DYKE_HIGH_ROW := 81

const TYPES := {
	# Walked on like the grass, but nothing is built on it, tilled or cut out of it.
	WorldObjectTypes.DYKE:
	{
		"connects": &"dyke",
		"slants": true,
		"turf": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": _DYKE_ROW,
		"look_rows": {DykeProfile.LOW: _DYKE_LOW_ROW, DykeProfile.HIGH: _DYKE_HIGH_ROW},
		"variants": 1,
	},
}
