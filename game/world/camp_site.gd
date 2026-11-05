class_name CampSite
extends RefCounted
## The starting camp: a fireplace and a sleeping bag in a small free clearing near the world
## centre. The sleeping bag lies vertically beside the fireplace, on the tile to its right and
## the one below that.

## The clearing is this many tiles wide and tall, centred on the fireplace.
const CLEARING_SIZE := 3
## Where the search gives up. Far beyond what any generated world needs.
const MAX_SEARCH_RADIUS := 64

const SLEEPING_BAG_OFFSET := Vector2i(1, 0)
## Below the fireplace and beside the sleeping bag, so the player can sleep straight away.
const SPAWN_OFFSET := Vector2i(0, 1)

var fireplace_pos: Vector2i
var sleeping_bag_pos: Vector2i
## The tile the player starts on.
var spawn_pos: Vector2i


## Finds the clearing nearest to the world centre and puts the camp objects in it.
## Searching rings of growing radius around (0, 0) is deterministic, and the first clearing
## found never needs objects removed. Generates the chunks it looks at into `world`.
static func create(world: World, generator: WorldGenerator) -> CampSite:
	for radius in MAX_SEARCH_RADIUS:
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				# Only the ring: the inside was searched by the smaller radii.
				if maxi(absi(x), absi(y)) != radius:
					continue
				var center := Vector2i(x, y)
				if _is_clearing(world, generator, center):
					return _place(world, center)
	assert(false, "No camp site found within %d tiles of the centre" % MAX_SEARCH_RADIUS)
	return null


static func _is_clearing(world: World, generator: WorldGenerator, center: Vector2i) -> bool:
	var reach := CLEARING_SIZE / 2
	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			var pos := Vector2i(x, y)
			_load_chunk_of(world, generator, pos)
			if not world.is_buildable(pos):
				return false
	return true


static func _load_chunk_of(world: World, generator: WorldGenerator, pos: Vector2i) -> void:
	var coords := Chunk.world_to_chunk(pos)
	if not world.is_chunk_loaded(coords) and World.is_chunk_in_bounds(coords):
		world.add_chunk(generator.generate_chunk(coords))


static func _place(world: World, center: Vector2i) -> CampSite:
	var camp := CampSite.new()
	camp.fireplace_pos = center
	camp.sleeping_bag_pos = center + SLEEPING_BAG_OFFSET
	camp.spawn_pos = center + SPAWN_OFFSET
	world.add_object(WorldObject.new(WorldObjectTypes.FIREPLACE, camp.fireplace_pos))
	world.add_object(WorldObject.new(WorldObjectTypes.SLEEPING_BAG, camp.sleeping_bag_pos))
	return camp
