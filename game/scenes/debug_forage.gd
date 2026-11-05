class_name DebugForage
extends RefCounted
## For screenshots (`--forage=<x>,<y>` in main.gd): a row of tiles with a stump, a picked and a
## berry bush and a planted sapling, and a few of each new item in the inventory. The chunks
## must be loaded.


static func create(state: GameState, origin: Vector2i) -> void:
	var picked := WorldObject.new(WorldObjectTypes.BERRY_BUSH, origin + Vector2i(1, 0))
	picked.pick()
	var stump := WorldObject.new(WorldObjectTypes.STUMP, origin)
	stump.state["tree"] = str(WorldObjectTypes.OAK)
	var sapling := WorldObject.new(WorldObjectTypes.SAPLING, origin + Vector2i(3, 0))
	sapling.state["tree"] = str(WorldObjectTypes.OAK)
	var objects: Array[WorldObject] = [
		stump,
		picked,
		WorldObject.new(WorldObjectTypes.BERRY_BUSH, origin + Vector2i(2, 0)),
		sapling
	]
	for object in objects:
		state.world.remove_object(object.pos)
		state.world.add_object(object)
	for item: StringName in [
		ItemTypes.WOOD, ItemTypes.STONE, ItemTypes.FIBRE, ItemTypes.BERRIES, ItemTypes.SAPLING
	]:
		state.player.inventory.add(item, 7)
