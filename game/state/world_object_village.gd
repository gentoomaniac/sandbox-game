class_name WorldObjectVillage
extends RefCounted
## The objects only the village puts into the world, as data, merged into WorldObjectTypes `TYPES`
## (see there for the entries): nobody takes them down, and no item places them but the notice
## board's (for the console's `give` and for pictures). Their atlas rows follow the ways' and the
## dead trees' (see tools/art/generate.py).

const _MARKET_STALL_ROW := 63
const _NOTICE_BOARD_ROW := 78

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
	# A plank board on two posts under a little roof, with notes pinned to it (issue #12).
	WorldObjectTypes.NOTICE_BOARD:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"atlas_row": _NOTICE_BOARD_ROW,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
}
