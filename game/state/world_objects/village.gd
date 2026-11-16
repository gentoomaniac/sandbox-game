class_name WorldObjectVillage
extends RefCounted
## The objects only the village puts into the world, as data, loaded into WorldObjectTypes `TYPES`
## (see there for the entries): nobody takes them down but the notice board, which an item places
## too: the village puts one on its square and the player may put one up anywhere (the console's
## `give`).
## Their atlas rows follow the ways' and the dead trees' (see tools/art/generate.py).

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
	# The village puts one on the square; the player may put one up anywhere outdoors with the
	# item (the console's `give`), and the axe takes it down for the item again.
	WorldObjectTypes.NOTICE_BOARD:
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"notice_board": 1},
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _NOTICE_BOARD_ROW,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
}
