class_name TrunkPlacement
extends RefCounted
## Where the trunk of a felled tree lies. A trunk is always horizontal: a long one (2x1) beside
## the stump, on the side away from the player when they stand left or right of the tree, and
## to the right (or else the left) when they stand above or below it. With no room for that
## there is a short one (1x1) on any free tile beside the stump, and with none, no trunk.


## Lays the trunk of `tree`, which has just been cut down and replaced by its stump, in `world`.
## `player_tile` is where the player felled it from. Returns the trunk, or null if there was no
## room.
static func lay(world: World, tree: WorldObject, player_tile: Vector2i) -> WorldObject:
	var away := Vector2i(signi(tree.pos.x - player_tile.x), 0)
	var sides: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT]
	if away.x != 0:
		sides = [away, -away]
	# Candidates in the order of preference: the long ones, then the short ones.
	var candidates: Array[WorldObject] = []
	for side in sides:
		# A long trunk's own tile is its left one, so on the left side that is two tiles over.
		var origin := tree.pos + (side if side.x > 0 else side * 2)
		candidates.append(WorldObject.new(WorldObjectTypes.trunk_type(tree.type, false), origin))
	sides.append_array([Vector2i.UP, Vector2i.DOWN])
	for side in sides:
		candidates.append(
			WorldObject.new(WorldObjectTypes.trunk_type(tree.type, true), tree.pos + side)
		)
	for trunk in candidates:
		if _has_room(world, trunk, player_tile):
			world.add_object(trunk)
			return trunk
	return null


static func _has_room(world: World, trunk: WorldObject, player_tile: Vector2i) -> bool:
	return trunk.tiles().all(
		func(tile: Vector2i) -> bool:
			return world.is_walkable(tile) and world.object_at(tile) == null and tile != player_tile
	)
