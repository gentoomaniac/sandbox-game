class_name TravelMaskCase
extends GutTest
## What the tests of the travel masks share: a world whose chunks are loaded, the masks of the
## same world, and the check that a mask answers what the loaded chunk answers (see
## design/villagers/travel.md).

const SEED := 7
## Seed 7: the coast and its sea dyke, with the fields behind them (a Knick, a wattle fence, a
## willow, reeds, boulders, ferns), and the first chunk of the tidal mud and of the sea.
const COAST := Vector2i(-9, -4)
const MUD := Vector2i(-14, -4)
## High water at the start of day 1, low water 372 minutes into it.
const HIGH_WATER_HOUR := 0
const LOW_WATER_HOUR := 6
const LOW_WATER_MINUTE := 12

var world: World
var masks: TravelMasks
var generator: WorldGenerator


func before_each() -> void:
	make_world(SEED)


func make_world(seed_value: int) -> void:
	world = World.new(seed_value)
	masks = TravelMasks.for_world(world)
	generator = WorldGenerator.new(seed_value)


## Loads the chunk, and the ones W, N and NW of it that a big object can reach it from.
func load_chunk_and_neighbours(coords: Vector2i) -> void:
	for step in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]:
		if World.is_chunk_in_bounds(coords + step) and not world.is_chunk_loaded(coords + step):
			world.add_chunk(generator.generate_chunk(coords + step))


func set_high_water() -> void:
	world.clock.set_time(HIGH_WATER_HOUR, 0)


func set_low_water() -> void:
	world.clock.set_time(LOW_WATER_HOUR, LOW_WATER_MINUTE)


## A tile of the chunk, by the position in it.
func tile_of(coords: Vector2i, local: Vector2i) -> Vector2i:
	return Chunk.to_world(coords, local)


## The tiles of the chunk where the mask and the loaded chunk disagree, at the clock's time: on
## whether a villager can stand there (buildings, which a mask does not know, are asked of the
## world), on whether the tile costs more for the object on it, and on whether it wears.
func disagreements(coords: Vector2i) -> Array[Vector2i]:
	var mask := masks.wait_for_mask(coords)
	var tide_level := Tide.level(world.clock.total_minutes())
	var day := world.clock.day
	var tiles: Array[Vector2i] = []
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var local := Vector2i(x, y)
			var tile := tile_of(coords, local)
			var object := world.object_at(tile)
			var is_free := world.building_at(tile) == null and mask.is_free(local, tide_level, day)
			var is_trampled := object != null and NpcTravel.is_trampled(object)
			if (
				is_free != Npcs.can_stand_at(world, Vector2(tile) + Vector2(0.5, 0.5))
				or mask.is_trampled(local, day) != is_trampled
				or mask.wears(local) != (world.tile_at(tile).wears() and not world.is_way_at(tile))
				or mask.is_way(local) != world.is_way_at(tile)
			):
				tiles.append(tile)
	return tiles


func assert_parity(coords: Vector2i, message := "") -> void:
	assert_eq(disagreements(coords), [] as Array[Vector2i], "%s %s" % [coords, message])


## The first tile of a loaded chunk that has an object of the type.
func find_object(coords: Vector2i, type: StringName) -> WorldObject:
	for object in world.chunk_at(coords).objects():
		if object.type == type:
			return object
	fail_test("no %s in the chunk %s" % [type, coords])
	return null


## The first tile of a loaded chunk with this terrain and nothing on it, with `length - 1` more like
## it to the east of it.
func empty_row(coords: Vector2i, terrain: Tile.Terrain, length := 1) -> Vector2i:
	for y in Chunk.CHUNK_SIZE:
		for x in range(Chunk.CHUNK_SIZE - length):
			var tiles: Array[Vector2i] = []
			for i in length:
				tiles.append(tile_of(coords, Vector2i(x + i, y)))
			if tiles.all(
				func(tile: Vector2i) -> bool:
					return world.tile_at(tile).terrain == terrain and world.object_at(tile) == null
			):
				return tiles[0]
	fail_test("no empty row of %d tiles in the chunk %s" % [length, coords])
	return Vector2i.ZERO


## Clears the tiles of a big object and puts it down on them, on grass.
func put_down_on_grass(type: StringName, tile: Vector2i) -> WorldObject:
	var object := WorldObject.new(type, tile)
	for covered in object.tiles():
		world.set_terrain(covered, Tile.Terrain.GRASS)
		world.remove_object(covered)
	world.add_object(object)
	return object


## Whether a villager can stand on a world tile by the mask of its chunk, at the clock's time.
func mask_is_free(tile: Vector2i) -> bool:
	return masks.wait_for_mask(Chunk.world_to_chunk(tile)).is_free(
		Chunk.local_pos(tile), Tide.level(world.clock.total_minutes()), world.clock.day
	)
