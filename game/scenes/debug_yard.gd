class_name DebugYard
extends RefCounted
## For screenshots (`--yard=<x>,<y>`): the things the player places and the lines across the
## land, side by side. In the row of the tile, eastwards and a tile apart: the chest, the
## workbench, the carved chest, the kiln and the oven. Three rows up, each running east and
## turning north at its end: a Knick, a wattle fence and a fieldstone wall; east of them a dyke
## on the slant, a stair of corners. Placed whatever the ground; loads the chunks it covers
## itself.

## The station types in the row of the tile.
const STATIONS: Array[StringName] = [
	WorldObjectTypes.CHEST,
	WorldObjectTypes.WORKBENCH,
	WorldObjectTypes.CARVED_CHEST,
	WorldObjectTypes.KILN,
	WorldObjectTypes.OVEN,
]
## The lines that run east and turn north, each this many tiles east of the last.
const LINES: Array[StringName] = [
	WorldObjectTypes.KNICK, WorldObjectTypes.WATTLE_FENCE, WorldObjectTypes.STONE_WALL
]
const LINE_SPACING := 5


static func create(world: World, origin: Vector2i) -> void:
	var objects: Array[WorldObject] = []
	for index in STATIONS.size():
		objects.append(WorldObject.new(STATIONS[index], origin + Vector2i(2 * index, 0)))
	for index in LINES.size():
		var start := origin + Vector2i(LINE_SPACING * index, -3)
		for tile: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]:
			objects.append(WorldObject.new(LINES[index], start + tile))
		for tile: Vector2i in [Vector2i(3, -1), Vector2i(3, -2)]:
			objects.append(WorldObject.new(LINES[index], start + tile))
	var dyke_start := origin + Vector2i(LINE_SPACING * LINES.size(), -6)
	for step in 4:
		objects.append(WorldObject.new(WorldObjectTypes.DYKE, dyke_start + Vector2i(step, step)))
		objects.append(
			WorldObject.new(WorldObjectTypes.DYKE, dyke_start + Vector2i(step + 1, step))
		)
	var generator := WorldGenerator.new(world.world_seed)
	for object in objects:
		for tile in object.tiles():
			var coords := Chunk.world_to_chunk(tile)
			if not world.is_chunk_loaded(coords):
				world.add_chunk(generator.generate_chunk(coords))
			world.remove_object(tile)
		world.add_object(object)
