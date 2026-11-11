class_name DebugDrops
extends RefCounted
## For screenshots (`--drops=<x>,<y>`): what a felled oak, a mined stone, a harvested
## turnip and a picked berry bush leave on the ground, in a row four tiles apart from there. The
## chunks around must be loaded.

const SPACING := 4


static func create(world: World, origin: Vector2i) -> void:
	var oak_pos := origin
	var stone_pos := origin + Vector2i(SPACING, 0)
	var crop_pos := origin + Vector2i(2 * SPACING, 0)
	var bush_pos := origin + Vector2i(3 * SPACING, 0)
	for pos in [oak_pos, stone_pos, crop_pos, bush_pos]:
		world.remove_object(pos)
	var stump := WorldObject.new(WorldObjectTypes.STUMP, oak_pos)
	stump.state["tree"] = str(WorldObjectTypes.OAK)
	world.add_object(stump)
	var oak_trunk: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.trunk_type(
		WorldObjectTypes.OAK, false
	)]
	world.drop_items(oak_pos, oak_trunk["drops"])
	world.drop_items(stone_pos, WorldObjectTypes.TYPES[WorldObjectTypes.STONE]["drops"])
	var crop := WorldObject.new(WorldObjectTypes.TURNIP, crop_pos)
	world.drop_items(crop_pos, CropLife.harvest_of(crop, RandomNumberGenerator.new()))
	var bush := WorldObject.new(WorldObjectTypes.BERRY_BUSH, bush_pos)
	bush.pick()
	world.add_object(bush)
	world.drop_items(bush_pos, bush.type_data()["drops"])
