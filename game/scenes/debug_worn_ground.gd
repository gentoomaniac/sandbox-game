class_name DebugWornGround
extends RefCounted
## For screenshots (`--worn-ground=<x>,<y>`): a yard worn by many feet, from that tile eastwards:
## a path in the middle, trodden ground round it, and single worn tiles and lines beyond, so every
## edge between the stages and the grass shows. Loads the chunks around it itself.

const WIDTH := 24
const HEIGHT := 14
## The wear of a tile in the middle of the path, and where the trodden rim ends (as a share of the
## distance from the middle to the edge of the yard).
const PATH_SHARE := 0.45
const TRODDEN_SHARE := 0.8
const CHUNK_REACH := 1


static func create(world: World, start: Vector2i) -> void:
	var generator := WorldGenerator.new(world.world_seed)
	var centre := Chunk.world_to_chunk(start + Vector2i(WIDTH / 2, HEIGHT / 2))
	for y in range(-CHUNK_REACH, CHUNK_REACH + 1):
		for x in range(-CHUNK_REACH, CHUNK_REACH + 1):
			var coords := centre + Vector2i(x, y)
			if not world.is_chunk_loaded(coords):
				world.add_chunk(generator.generate_chunk(coords))
	var middle := Vector2(WIDTH, HEIGHT) / 2.0
	for y in HEIGHT:
		for x in WIDTH:
			# An oval of wear that thins out towards its edge, rough with the position hash.
			var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - middle) / middle
			var share := offset.length() + (PositionHash.of(Vector2i(x, y), 7) % 5) * 0.05 - 0.1
			var tile := start + Vector2i(x, y)
			if share < PATH_SHARE:
				world.wear_tile(tile, 30.0)
			elif share < TRODDEN_SHARE:
				world.wear_tile(tile, 10.0)
	# Islands of a single worn tile, and a short line, out on the grass.
	for island in [Vector2i(-3, 2), Vector2i(-3, 5), Vector2i(-5, 9)]:
		world.wear_tile(start + island, 30.0)
	for x in 5:
		world.wear_tile(start + Vector2i(-8 + x, 12), 10.0)
