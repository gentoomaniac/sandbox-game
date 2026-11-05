class_name DebugFelled
extends RefCounted
## For screenshots (`--felled=<x>,<y>` in main.gd): an oak felled from the left, one from the
## right, a spruce from above, a pine from below and a dead tree from the left, in a row five
## tiles apart from there, and the three tree seeds on the ground below. The chunks around must
## be loaded.

const SPACING := 5
## The tiles cleared around each tree, from its own.
const CLEARED := Rect2i(-2, -1, 5, 3)
## Each tree with the side the player felled it from.
const FELLINGS := [
	[WorldObjectTypes.OAK, Vector2i.LEFT],
	[WorldObjectTypes.OAK, Vector2i.RIGHT],
	[WorldObjectTypes.SPRUCE, Vector2i.UP],
	[WorldObjectTypes.PINE, Vector2i.DOWN],
	[WorldObjectTypes.DEAD_TREE, Vector2i.LEFT],
]
const SEEDS := [ItemTypes.ACORN, ItemTypes.SPRUCE_CONE, ItemTypes.PINE_CONE]


static func create(world: World, origin: Vector2i) -> void:
	for index in FELLINGS.size():
		var tree_pos := origin + Vector2i(index * SPACING, 0)
		for y in CLEARED.size.y:
			for x in CLEARED.size.x:
				world.remove_object(tree_pos + CLEARED.position + Vector2i(x, y))
		var tree_type: StringName = FELLINGS[index][0]
		var player_tile: Vector2i = tree_pos + FELLINGS[index][1]
		var stump := WorldObject.new(WorldObjectTypes.TYPES[tree_type]["leaves"], tree_pos)
		if WorldObjectTypes.TYPES[tree_type].get("regrows", false):
			stump.state["tree"] = str(tree_type)
		world.add_object(stump)
		TrunkPlacement.lay(world, WorldObject.new(tree_type, tree_pos), player_tile)
	for index in SEEDS.size():
		var pos := origin + Vector2i(index * 2, 3)
		world.add_ground_item(GroundItem.new(SEEDS[index], 1, Vector2(pos) + Vector2(0.5, 0.5)))
