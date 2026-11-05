class_name WorldGenerator
extends RefCounted
## Generates the grassland biome: grass with one meandering river running west to east, a
## floodplain band along both banks and wetland patches, with forests (oak or conifer
## stands, mixed at their borders), bushes, rare dead trees and scattered stones and boulders
## on the grass.
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
## boulder, dead tree or nothing, so a tile never has two objects. The tree chance rises from
## the edge of a forest to its core (noise at FOREST_CORE_THRESHOLD and above), where crowns
## overlap: they are about 3 tiles wide, so a quarter of the tiles holding a trunk is a dense
## forest. Bushes are the other way round, common at the edge and in clearings.
const FOREST_THRESHOLD := 0.1
const FOREST_CORE_THRESHOLD := 0.35
const FOREST_EDGE_TREE_CHANCE := 0.05
const FOREST_CORE_TREE_CHANCE := 0.22
const CLEARING_TREE_CHANCE := 0.003
const FOREST_EDGE_BUSH_CHANCE := 0.08
const FOREST_CORE_BUSH_CHANCE := 0.01
const CLEARING_BUSH_CHANCE := 0.02
const STONE_CHANCE := 0.012
## A boulder is 2 tiles wide: it needs the tile right of the rolled one to be free grass.
const BOULDER_CHANCE := 0.004
## Dead trees are rare everywhere, and more common with wetland WETLAND_REACH tiles away.
const DEAD_TREE_CHANCE := 0.0015
const DEAD_TREE_NEAR_WETLAND_CHANCE := 0.02
const WETLAND_REACH := 5

## Tall grass grows in meadows: where the forest noise is below MEADOW_BELOW, in patches
## where the grass noise is above GRASS_PATCH_ABOVE (thick) and thinly elsewhere.
const MEADOW_BELOW := -0.1
const GRASS_PATCH_ABOVE := 0.1
const GRASS_PATCH_CHANCE := 0.6
const GRASS_SCATTER_CHANCE := 0.04

## Reeds stand on the banks: on floodplain with water within REEDS_REACH tiles, and at the edges
## of wetland (a wetland tile next to a tile that is not wetland). They grow in stands where the
## grass noise is above REED_STAND_ABOVE (thick) and thinly elsewhere.
const REEDS_REACH := 2
const REED_STAND_ABOVE := 0.0
const REED_STAND_CHANCE := 0.75
const REED_SCATTER_CHANCE := 0.12

## Clay spots are grass tiles with water or wetland within CLAY_REACH tiles, in the clusters
## where the clay noise is above CLAY_CLUSTER_ABOVE, of which CLAY_SPOT_CHANCE are spots. A
## grass tile is as far as 3 tiles from the river's water (the floodplain lies between).
const CLAY_REACH := 5
const CLAY_CLUSTER_ABOVE := 0.25
const CLAY_SPOT_CHANCE := 0.5

## The 8 directions probed for wetland and, for clay, for water.
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
const GRASS_FREQUENCY := 0.05
const CLAY_FREQUENCY := 0.15

## Offsets the wetland seed so it is independent of the river noise.
const WETLAND_SEED_OFFSET := 1
const FOREST_SEED_OFFSET := 2
const COMPOSITION_SEED_OFFSET := 4
const GRASS_SEED_OFFSET := 6
const CLAY_SEED_OFFSET := 7
## Offsets the per-tile object rolls from the noise seeds: one decides the kind of object,
## the other which variety of tree or bush.
const OBJECT_ROLL_SEED_OFFSET := 3
const VARIETY_ROLL_SEED_OFFSET := 5
const GRASS_ROLL_SEED_OFFSET := 8
const CLAY_ROLL_SEED_OFFSET := 9
const REED_ROLL_SEED_OFFSET := 10

var _river_noise := FastNoiseLite.new()
var _wetland_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _composition_noise := FastNoiseLite.new()
var _grass_noise := FastNoiseLite.new()
var _clay_noise := FastNoiseLite.new()
var _object_roll_seed: int
var _variety_roll_seed: int
var _grass_roll_seed: int
var _clay_roll_seed: int
var _reed_roll_seed: int


func _init(world_seed: int) -> void:
	_river_noise.seed = world_seed
	_river_noise.frequency = RIVER_FREQUENCY
	_wetland_noise.seed = world_seed + WETLAND_SEED_OFFSET
	_wetland_noise.frequency = WETLAND_FREQUENCY
	_forest_noise.seed = world_seed + FOREST_SEED_OFFSET
	_forest_noise.frequency = FOREST_FREQUENCY
	_composition_noise.seed = world_seed + COMPOSITION_SEED_OFFSET
	_composition_noise.frequency = COMPOSITION_FREQUENCY
	_grass_noise.seed = world_seed + GRASS_SEED_OFFSET
	_grass_noise.frequency = GRASS_FREQUENCY
	_clay_noise.seed = world_seed + CLAY_SEED_OFFSET
	_clay_noise.frequency = CLAY_FREQUENCY
	_object_roll_seed = world_seed + OBJECT_ROLL_SEED_OFFSET
	_variety_roll_seed = world_seed + VARIETY_ROLL_SEED_OFFSET
	_grass_roll_seed = world_seed + GRASS_ROLL_SEED_OFFSET
	_clay_roll_seed = world_seed + CLAY_ROLL_SEED_OFFSET
	_reed_roll_seed = world_seed + REED_ROLL_SEED_OFFSET


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
## position and the terrain; only grass has objects, but for the reeds on the banks. A boulder
## covers the tile to its right, which therefore has to be free grass: otherwise there is no
## boulder.
func object_type_at(world_pos: Vector2i, terrain: Tile.Terrain) -> StringName:
	if terrain == Tile.Terrain.FLOODPLAIN or terrain == Tile.Terrain.WETLAND:
		return WorldObjectTypes.REEDS if _is_reeds_at(world_pos, terrain) else &""
	var object_type := _rolled_type_at(world_pos, terrain)
	if object_type != WorldObjectTypes.BOULDER:
		return object_type
	var right := world_pos + Vector2i.RIGHT
	if (
		terrain_at(right) == Tile.Terrain.GRASS
		and _rolled_type_at(right, Tile.Terrain.GRASS) == &""
	):
		return object_type
	return &""


## What the roll of a tile says, before a boulder is checked for room.
func _rolled_type_at(world_pos: Vector2i, terrain: Tile.Terrain) -> StringName:
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
	if roll < STONE_CHANCE + BOULDER_CHANCE:
		return WorldObjectTypes.STONE if roll < STONE_CHANCE else WorldObjectTypes.BOULDER
	roll -= STONE_CHANCE + BOULDER_CHANCE
	if (
		roll < DEAD_TREE_NEAR_WETLAND_CHANCE
		and (roll < DEAD_TREE_CHANCE or _is_near_wetland(world_pos))
	):
		return WorldObjectTypes.DEAD_TREE
	var is_tall_grass := forest_noise < MEADOW_BELOW and _is_tall_grass_at(world_pos)
	return WorldObjectTypes.TALL_GRASS if is_tall_grass else &""


func _is_tall_grass_at(world_pos: Vector2i) -> bool:
	var in_patch := _grass_noise.get_noise_2dv(Vector2(world_pos)) > GRASS_PATCH_ABOVE
	var chance := GRASS_PATCH_CHANCE if in_patch else GRASS_SCATTER_CHANCE
	return _roll(world_pos, _grass_roll_seed) < chance


func _is_reeds_at(world_pos: Vector2i, terrain: Tile.Terrain) -> bool:
	# The roll is the cheap part: only a tile that can still pass it is probed for water.
	var roll := _roll(world_pos, _reed_roll_seed)
	if roll >= maxf(REED_STAND_CHANCE, REED_SCATTER_CHANCE):
		return false
	var is_bank := (
		_is_wetland_edge(world_pos)
		if terrain == Tile.Terrain.WETLAND
		else _is_water_within(world_pos, REEDS_REACH)
	)
	if not is_bank:
		return false
	var in_stand := _grass_noise.get_noise_2dv(Vector2(world_pos)) > REED_STAND_ABOVE
	var chance := REED_STAND_CHANCE if in_stand else REED_SCATTER_CHANCE
	return roll < chance


func _is_water_within(world_pos: Vector2i, reach: int) -> bool:
	for distance in range(1, reach + 1):
		for direction in WETLAND_PROBE_DIRECTIONS:
			if terrain_at(world_pos + direction * distance) == Tile.Terrain.WATER:
				return true
	return false


func _is_wetland_edge(world_pos: Vector2i) -> bool:
	for direction in WETLAND_PROBE_DIRECTIONS:
		if terrain_at(world_pos + direction) != Tile.Terrain.WETLAND:
			return true
	return false


## Whether a tile is a spot with clay in it (see CLAY_REACH): a pure function of the seed and
## the position. Spots are only where no object is generated, so the shovel can reach them.
func is_clay_spot(world_pos: Vector2i) -> bool:
	if (
		_clay_noise.get_noise_2dv(Vector2(world_pos)) <= CLAY_CLUSTER_ABOVE
		or _roll(world_pos, _clay_roll_seed) >= CLAY_SPOT_CHANCE
		or terrain_at(world_pos) != Tile.Terrain.GRASS
		or object_type_at(world_pos, Tile.Terrain.GRASS) != &""
	):
		return false
	# Water and wetland patches are wide, so probing the 8 directions finds them.
	for distance in range(1, CLAY_REACH + 1):
		for direction in WETLAND_PROBE_DIRECTIONS:
			var terrain := terrain_at(world_pos + direction * distance)
			if terrain == Tile.Terrain.WATER or terrain == Tile.Terrain.WETLAND:
				return true
	return false


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
