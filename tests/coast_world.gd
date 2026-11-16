class_name CoastWorld
extends RefCounted
## A world with the chunks of a stretch of the sea dyke loaded, for the tests of the storm surge.

const SEED := 42
## The chunks that hold the sea dyke and the land behind it, for the rows of a few chunks.
const CHUNK_COLUMNS := Vector2i(-12, -3)
const CHUNK_ROWS := Vector2i(0, 2)


static func make() -> World:
	var world := World.new(SEED)
	load_chunks(world)
	return world


## Loads those chunks into a world of the seed, as far as it has not got them.
static func load_chunks(world: World) -> void:
	var generator := WorldGenerator.new(SEED)
	for y in range(CHUNK_ROWS.x, CHUNK_ROWS.y):
		for x in range(CHUNK_COLUMNS.x, CHUNK_COLUMNS.y):
			if not world.is_chunk_loaded(Vector2i(x, y)):
				world.add_chunk(generator.generate_chunk(Vector2i(x, y)))


## The sea dyke objects of the loaded chunks.
static func sea_dykes(world: World) -> Array[WorldObject]:
	var dykes: Array[WorldObject] = []
	for coords in world.loaded_chunk_coords():
		for object in world.chunk_at(coords).objects():
			if object.type == WorldObjectTypes.DYKE and world.dykes.is_sea_dyke(object.pos):
				dykes.append(object)
	return dykes
