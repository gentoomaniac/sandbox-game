class_name WorldObjectStall
extends RefCounted
## The player's stall as data, merged into WorldObjectTypes `TYPES` (see there for the entries): the
## hand cart with a board (#49), which they stock and villagers buy from (see SalesCart). It
## wears the carved chest's picture until it has art of its own (see tools/art/generate.py).

const SALES_CART := &"sales_cart"
const _SALES_CART_ROW := 79

const TYPES := {
	SALES_CART:
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"sales_cart": 1},
		"storage_slots": 10,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _SALES_CART_ROW,
		"variants": 1,
		"interior_sprite": "res://assets/interior/carved_chest.png",
		"placeable_in": WorldObjectTypes.ANYWHERE,
	},
}
