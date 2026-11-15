class_name WorldObjectVillage
extends RefCounted
## The objects only the village puts into the world, as data, merged into WorldObjectTypes `TYPES`
## (see there for the entries): no item places them and nobody takes them down. Their atlas rows
## follow the ways' (see tools/art/generate.py).

const _MARKET_STALL_ROW := 63

const TYPES := {
	# A counter under an awning, on 2x1 tiles, for the keeper of the shop (issue #10).
	WorldObjectTypes.MARKET_STALL:
	{
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"atlas_row": _MARKET_STALL_ROW,
		"variants": 1,
	},
}
