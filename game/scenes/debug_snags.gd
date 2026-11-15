class_name DebugSnags
extends RefCounted
## For screenshots (`--snags=<x>,<y>`): a wood on a clearing of grass, a kind of tree to each
## column from that tile eastwards, and down the rows the living, the dead and the half-dead
## trees of it. The chunks around must be loaded.

const COLUMN_SPACING := 3
const ROW_SPACING := 5
const GRASS_MARGIN := 3


static func create(world: World, origin: Vector2i) -> void:
	var kinds := WorldObjectSnags.KINDS
	for y in range(-GRASS_MARGIN - 4, 3 * ROW_SPACING + GRASS_MARGIN):
		for x in range(-GRASS_MARGIN, kinds.size() * COLUMN_SPACING + GRASS_MARGIN):
			var pos := origin + Vector2i(x, y)
			world.remove_object(pos)
			world.set_terrain(pos, Tile.Terrain.GRASS)
	for column in kinds.size():
		var types: Array[StringName] = [
			kinds[column],
			WorldObjectSnags.dead_type(kinds[column]),
			WorldObjectSnags.half_dead_type(kinds[column]),
		]
		for row in types.size():
			var pos := origin + Vector2i(column * COLUMN_SPACING, row * ROW_SPACING)
			world.add_object(WorldObject.new(types[row], pos))
