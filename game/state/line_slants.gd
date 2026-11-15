class_name LineSlants
extends RefCounted
## Where a line object that `slants` (the dyke, see WorldObjectTypes) runs on the diagonal: it is
## laid tile by tile and joins its neighbours on their sides, so on the slant it is a stair of
## corners. A corner (joined on two sides that meet) whose neighbour across one of them is a corner
## turning the other way is a step of such a stair, and the line crosses that side on the
## diagonal; a stair of steps is one straight line running corner to corner across the land
## (tools/art/slants.py draws it).


## The sides `object` crosses on the slant, as bits like World `connections`. Depends on the
## neighbours' neighbours, which World `type_standing_at` also tells in chunks that are not loaded,
## so a line drawn at a chunk border slants on into the chunk before it loads.
static func slanted_sides(world: World, object: WorldObject) -> int:
	var group: StringName = object.type_data()["connects"]
	return slanted_sides_at(object.pos, _connections_at.bind(world, group))


## The sides of `world_pos` with an object of the line `group`, as World `connections` counts them.
static func _connections_at(world_pos: Vector2i, world: World, group: StringName) -> int:
	var mask := 0
	for side in World.CONNECTION_SIDES.size():
		var type := world.type_standing_at(world_pos + World.CONNECTION_SIDES[side])
		if type != &"" and WorldObjectTypes.TYPES[type].get("connects") == group:
			mask |= 1 << side
	return mask


## `slanted_sides` of the line on `world_pos`, where `connections_at.call(tile)` gives the sides a
## tile of the line joins (tools/world_map.gd asks it of the generated land).
static func slanted_sides_at(world_pos: Vector2i, connections_at: Callable) -> int:
	var mask: int = connections_at.call(world_pos)
	if not mask in WorldObjectTypes.CORNER_MASKS:
		return 0
	# The neighbour of a step is joined on the sides opposite to this one's.
	var step_mask := ((mask << 2) | (mask >> 2)) & 0b1111
	var slanted := 0
	for side in World.CONNECTION_SIDES.size():
		if (
			mask & (1 << side)
			and connections_at.call(world_pos + World.CONNECTION_SIDES[side]) == step_mask
		):
			slanted |= 1 << side
	return slanted
