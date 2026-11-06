class_name DebugChest
extends RefCounted
## For screenshots (`--chest=<x>,<y>` and `--chest-inside=<x>,<y>`): a chest with
## a few items in it.

const CONTENTS := {
	ItemTypes.LOGS: 12,
	ItemTypes.STONE: 7,
	ItemTypes.TURNIP: 3,
	ItemTypes.BERRIES: 25,
	ItemTypes.CLAY: 4,
}


## Puts a chest on a tile of `map` (the world's chunk must be loaded), and returns it.
static func create(map: GameMap, tile: Vector2i) -> WorldObject:
	var chest := WorldObject.new(WorldObjectTypes.CHEST, tile)
	for item: StringName in CONTENTS:
		chest.storage.add(item, CONTENTS[item])
	map.remove_object(tile)
	map.add_object(chest)
	return chest
