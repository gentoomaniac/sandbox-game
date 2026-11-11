class_name DebugItems
extends RefCounted
## For screenshots (`--items=<x>,<y>`): one of every item lying on the ground, ten to a row a
## tile apart from that tile eastwards and southwards, and in the inventory one of every item
## that still fits in it, so the character screen (`--inventory`) shows their icons. Put the
## player out of reach of the rows (`--at=`), or the items are collected.

const PER_ROW := 10
## What `--floor-items` lays in a row.
const FLOOR_ITEMS: Array[StringName] = [
	ItemTypes.LOGS, ItemTypes.STONE, ItemTypes.TURNIP, ItemTypes.HAY, ItemTypes.CLAY
]


static func create(state: GameState, origin: Vector2i) -> void:
	var index := 0
	for item: StringName in ItemTypes.TYPES:
		var tile := origin + Vector2i(index % PER_ROW, index / PER_ROW)
		state.world.ground_items.add(GroundItem.new(item, 1, Vector2(tile) + Vector2(0.5, 0.5)))
		index += 1
		if state.player.inventory.count_of(item) == 0:
			state.player.inventory.add(item, 1)


## For screenshots (`--floor-items=<x>,<y>`): a row of piles on the floor of the room the player is
## in, from that tile eastwards. Out of the player's reach, or they are collected.
static func lay_on_floor(map: GameMap, origin: Vector2i) -> void:
	for index in FLOOR_ITEMS.size():
		var tile := origin + Vector2i(index, 0)
		var position := Vector2(tile) + Vector2(0.5, 0.5)
		map.ground_items.add(GroundItem.new(FLOOR_ITEMS[index], index + 1, position))
