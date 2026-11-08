class_name DebugItems
extends RefCounted
## For screenshots (`--items=<x>,<y>`): one of every item lying on the ground, ten to a row a
## tile apart from that tile eastwards and southwards, and in the inventory one of every item
## that still fits in it, so the character screen (`--inventory`) shows their icons. Put the
## player out of reach of the rows (`--at=`), or the items are collected.

const PER_ROW := 10


static func create(state: GameState, origin: Vector2i) -> void:
	var index := 0
	for item: StringName in ItemTypes.TYPES:
		var tile := origin + Vector2i(index % PER_ROW, index / PER_ROW)
		state.world.ground_items.add(GroundItem.new(item, 1, Vector2(tile) + Vector2(0.5, 0.5)))
		index += 1
		if state.player.inventory.count_of(item) == 0:
			state.player.inventory.add(item, 1)
