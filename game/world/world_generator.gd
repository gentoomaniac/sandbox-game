class_name WorldGenerator
extends RefCounted
## Generates the grassland biome: grass with one meandering river running west to east, a
## floodplain band along both banks and wetland patches, with forests (oak or conifer
## stands, mixed at their borders), bushes, rare dead trees and scattered stones on the grass.
##
## Deterministic: terrain is a pure function of the seed and the world tile position, and
## each generator owns its noise instances, so chunks come out the same in any order and
## fit together seamlessly.

## Tiles from the river centre line to the bank (so the river is twice as wide).
const RIVER_HALF_WIDTH := 3.0
## Tiles from the bank to the edge of the floodplain.
const FLOODPLAIN_WIDTH := 3.0
## How far (in tiles) the river's centre line wanders north and south of y = 0.
const RIVER_MEANDER_AMPLITUDE := 150.0
## Wetland appears where the second noise is above this (dry land only).
const WETLAND_THRESHOLD := 0.45

## Forests are where the forest noise is above this; trees fill a forest densely and are
## rare outside it. Chances are per grass tile; one roll per tile decides tree, bush, stone,
## dead tree or nothing, so a tile never has two objects. The tree chance rises from the
## edge of a forest to its core (noise at FOREST_CORE_THRESHOLD and above), where crowns
## overlap; bushes are the other way round, common at the edge and in clearings.
const FOREST_THRESHOLD := 0.1
const FOREST_CORE_THRESHOLD := 0.35
const FOREST_EDGE_TREE_CHANCE := 0.12
const FOREST_CORE_TREE_CHANCE := 0.55
const CLEARING_TREE_CHANCE := 0.004
const FOREST_EDGE_BUSH_CHANCE := 0.08
const FOREST_CORE_BUSH_CHANCE := 0.01
const CLEARING_BUSH_CHANCE := 0.02
const STONE_CHANCE := 0.012
## Dead trees are rare everywhere, and more common with wetland WETLAND_REACH tiles away.
const DEAD_TREE_CHANCE := 0.0015
const DEAD_TREE_NEAR_WETLAND_CHANCE := 0.02
const WETLAND_REACH := 5

## The 8 directions probed for wetland.
const WETLAND_PROBE_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
]

## Which trees a forest has: the composition noise says oak (negative) or conifer
## (positive); the conifer share is 0.5 + noise * this, clamped, so stands are mostly one
## kind with mixed borders. Of the conifers, this share is spruce and the rest pine.
const CONIFER_SHARE_SLOPE := 2.0
const SPRUCE_SHARE_OF_CONIFERS := 0.6
## The bush kinds as cumulative shares of the bush roll, in order.
const BUSH_KIND_SHARES := [
	[0.3, WorldObjectTypes.BERRY_BUSH],
	[0.6, WorldObjectTypes.SHRUB],
	[0.8, WorldObjectTypes.FERN_BUSH],
	[1.0, WorldObjectTypes.SAPLING],
]

## Features per tile; lower is larger and smoother.
const RIVER_FREQUENCY := 0.004
const WETLAND_FREQUENCY := 0.03
const FOREST_FREQUENCY := 0.02
const COMPOSITION_FREQUENCY := 0.012

## Offsets the wetland seed so it is independent of the river noise.
const WETLAND_SEED_OFFSET := 1
const FOREST_SEED_OFFSET := 2
const COMPOSITION_SEED_OFFSET := 4
## Offsets the per-tile object rolls from the noise seeds: one decides the kind of object,
## the other which variety of tree or bush.
const OBJECT_ROLL_SEED_OFFSET := 3
const VARIETY_ROLL_SEED_OFFSET := 5

var _river_noise := FastNoiseLite.new()
var _wetland_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _composition_noise := FastNoiseLite.new()
var _object_roll_seed: int
var _variety_roll_seed: int


func _init(world_seed: int) -> void:
	_river_noise.seed = world_seed
	_river_noise.frequency = RIVER_FREQUENCY
	_wetland_noise.seed = world_seed + WETLAND_SEED_OFFSET
	_wetland_noise.frequency = WETLAND_FREQUENCY
	_forest_noise.seed = world_seed + FOREST_SEED_OFFSET
	_forest_noise.frequency = FOREST_FREQUENCY
	_composition_noise.seed = world_seed + COMPOSITION_SEED_OFFSET
	_composition_noise.frequency = COMPOSITION_FREQUENCY
	_object_roll_seed = world_seed + OBJECT_ROLL_SEED_OFFSET
	_variety_roll_seed = world_seed + VARIETY_ROLL_SEED_OFFSET


## The chunk at `chunk_coords`, or null if it is outside the world bounds.
func generate_chunk(chunk_coords: Vector2i) -> Chunk:
	if not World.is_chunk_in_bounds(chunk_coords):
		return null
	var chunk := Chunk.new(chunk_coords)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var local := Vector2i(x, y)
			var world_pos := Chunk.to_world(chunk_coords, local)
			var terrain := terrain_at(world_pos)
			chunk.set_terrain(local, terrain)
			var object_type := object_type_at(world_pos, terrain)
			if object_type != &"":
				chunk.add_object(WorldObject.new(object_type, world_pos))
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


## The type of object generated on a tile, or &"" for none. A pure function of the seed, the
## position and the terrain; only grass has objects.
func object_type_at(world_pos: Vector2i, terrain: Tile.Terrain) -> StringName:
	if terrain != Tile.Terrain.GRASS:
		return &""
	var forest_noise := _forest_noise.get_noise_2dv(Vector2(world_pos))
	var tree_chance := CLEARING_TREE_CHANCE
	var bush_chance := CLEARING_BUSH_CHANCE
	if forest_noise > FOREST_THRESHOLD:
		var depth := clampf(
			(forest_noise - FOREST_THRESHOLD) / (FOREST_CORE_THRESHOLD - FOREST_THRESHOLD), 0.0, 1.0
		)
		tree_chance = lerpf(FOREST_EDGE_TREE_CHANCE, FOREST_CORE_TREE_CHANCE, depth)
		bush_chance = lerpf(FOREST_EDGE_BUSH_CHANCE, FOREST_CORE_BUSH_CHANCE, depth)
	# Hashes of the position instead of a shared RNG, so the rolls do not depend on the
	# order chunks are generated in.
	var roll := _roll(world_pos, _object_roll_seed)
	if roll < tree_chance:
		return _tree_type_at(world_pos, _roll(world_pos, _variety_roll_seed))
	roll -= tree_chance
	if roll < bush_chance:
		return _bush_type(_roll(world_pos, _variety_roll_seed))
	roll -= bush_chance
	if roll < STONE_CHANCE:
		return WorldObjectTypes.STONE
	roll -= STONE_CHANCE
	if (
		roll < DEAD_TREE_NEAR_WETLAND_CHANCE
		and (roll < DEAD_TREE_CHANCE or _is_near_wetland(world_pos))
	):
		return WorldObjectTypes.DEAD_TREE
	return &""


## A float in [0, 1) from a position hash.
func _roll(world_pos: Vector2i, salt: int) -> float:
	return PositionHash.of(world_pos, salt) % 10000 / 10000.0


## Oak, spruce or pine, by the forest composition at the tile; `variety_roll` in [0, 1).
func _tree_type_at(world_pos: Vector2i, variety_roll: float) -> StringName:
	var composition := _composition_noise.get_noise_2dv(Vector2(world_pos))
	var conifer_share := clampf(0.5 + composition * CONIFER_SHARE_SLOPE, 0.0, 1.0)
	if variety_roll >= conifer_share:
		return WorldObjectTypes.OAK
	if variety_roll < conifer_share * SPRUCE_SHARE_OF_CONIFERS:
		return WorldObjectTypes.SPRUCE
	return WorldObjectTypes.PINE


func _bush_type(variety_roll: float) -> StringName:
	for entry: Array in BUSH_KIND_SHARES:
		if variety_roll < entry[0]:
			return entry[1]
	return BUSH_KIND_SHARES[-1][1]


func _is_near_wetland(world_pos: Vector2i) -> bool:
	for direction in WETLAND_PROBE_DIRECTIONS:
		if terrain_at(world_pos + direction * WETLAND_REACH) == Tile.Terrain.WETLAND:
			return true
	return false
