class_name WorldGenerator
extends RefCounted
## Generates the grassland biome: grass with one meandering river running west to east, a
## floodplain band along both banks and wetland patches.
##
## Deterministic: terrain is a pure function of the seed and the world tile position, and
## each generator owns its noise instances, so chunks come out the same in any order and
## fit together seamlessly.

## Tiles from the river centre line to the bank (so the river is twice as wide).
const RIVER_HALF_WIDTH := 3.0
## Tiles from the bank to the edge of the floodplain.
const FLOODPLAIN_WIDTH := 6.0
## How far (in tiles) the river's centre line wanders north and south of y = 0.
const RIVER_MEANDER_AMPLITUDE := 150.0
## Wetland appears where the second noise is above this (dry land only).
const WETLAND_THRESHOLD := 0.45

## Features per tile; lower is larger and smoother.
const RIVER_FREQUENCY := 0.004
const WETLAND_FREQUENCY := 0.03

## Offsets the wetland seed so it is independent of the river noise.
const WETLAND_SEED_OFFSET := 1

var _river_noise := FastNoiseLite.new()
var _wetland_noise := FastNoiseLite.new()


func _init(world_seed: int) -> void:
	_river_noise.seed = world_seed
	_river_noise.frequency = RIVER_FREQUENCY
	_wetland_noise.seed = world_seed + WETLAND_SEED_OFFSET
	_wetland_noise.frequency = WETLAND_FREQUENCY


## The chunk at `chunk_coords`, or null if it is outside the world bounds.
func generate_chunk(chunk_coords: Vector2i) -> Chunk:
	if not World.is_chunk_in_bounds(chunk_coords):
		return null
	var chunk := Chunk.new(chunk_coords)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var local := Vector2i(x, y)
			chunk.set_terrain(local, terrain_at(Chunk.to_world(chunk_coords, local)))
	return chunk


## The one place that decides what a world tile is.
func terrain_at(world_pos: Vector2i) -> Tile.Terrain:
	# The river is a centre line y = f(x) rather than a noise isoline: an isoline can fade
	# out or leave isolated pools, but this one is always continuous and the floodplain
	# distance is exact.
	var river_y := _river_noise.get_noise_1d(world_pos.x) * RIVER_MEANDER_AMPLITUDE
	var river_distance := absf(world_pos.y - river_y)
	if river_distance < RIVER_HALF_WIDTH:
		return Tile.Terrain.WATER
	if river_distance < RIVER_HALF_WIDTH + FLOODPLAIN_WIDTH:
		return Tile.Terrain.FLOODPLAIN
	if _wetland_noise.get_noise_2d(world_pos.x, world_pos.y) > WETLAND_THRESHOLD:
		return Tile.Terrain.WETLAND
	return Tile.Terrain.GRASS
