class_name WorldGenerator
extends RefCounted
## Generates the grassland biome: grass with one winding river running west to east, a few creeks
## to it (with fords), a floodplain band along both banks and wetland patches. What grows on the
## grass (woods, bushes, rare dead trees, stones and boulders) is VegetationPlacement's.
##
## The open land is bare: no fields, fences, hedges, walls or ditches are generated in it (those
## come with the villages, and the player digs ditches). The only work of men in it is the dykes
## of DykeLayout (data/landscape.cfg), along the floodplain's edge and the coast.
##
## In the west lies the North Sea, which CoastLayout makes: the sea dyke stands on the first land
## and its marsh reaches inland from it as from the river; west of the coast line lies the
## foreshore, which nothing grows on but for the Warften and Ewers of CoastLayout.
##
## Deterministic: terrain is a pure function of the seed and the world tile position, and
## each generator owns its noise instances, so chunks come out the same in any order and
## fit together seamlessly.

## Tiles from the river centre line to the bank (so the river is twice as wide).
const RIVER_HALF_WIDTH := 3.0
## What a tile of a creek is: its water, a ford (shallow ground, walked over like the floodplain)
## and the small wetland the creek starts in.
const CREEK_TERRAINS := {
	CreekLayout.Bed.WATER: Tile.Terrain.WATER,
	CreekLayout.Bed.FORD: Tile.Terrain.FLOODPLAIN,
	CreekLayout.Bed.SOURCE: Tile.Terrain.WETLAND,
}
## Tiles from the bank to the edge of the floodplain.
const FLOODPLAIN_WIDTH := 3.0
## Wetland appears where the second noise is above this (dry land only).
const WETLAND_THRESHOLD := 0.45

## How far (in tiles) from a tile wetland counts as near it, for the kinds of trees and the snags.
const WETLAND_REACH := 5

## Clay spots are grass tiles with water (the river) or wetland within CLAY_REACH
## tiles, in the clusters where the clay noise is above CLAY_CLUSTER_ABOVE, of which
## CLAY_SPOT_CHANCE are spots. A grass tile is as far as 3 tiles from the river's water (the
## floodplain lies between).
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

## Features per tile; lower is larger and smoother.
const WETLAND_FREQUENCY := 0.03
const CLAY_FREQUENCY := 0.15
## Offsets the wetland seed so it is independent of the river noise.
const WETLAND_SEED_OFFSET := 1
const CLAY_SEED_OFFSET := 7
const CLAY_ROLL_SEED_OFFSET := 9

var _river: RiverLine
var _creeks: CreekLayout
var _wetland_noise := FastNoiseLite.new()
var _clay_noise := FastNoiseLite.new()
var _coast: CoastLayout
var _dykes: DykeLayout
var _vegetation: VegetationPlacement
var _clay_roll_seed: int


func _init(world_seed: int, landscape := LandscapeRules.default_rules()) -> void:
	_river = RiverLine.new(world_seed)
	_creeks = CreekLayout.new(world_seed, _river, landscape)
	_coast = CoastLayout.new(world_seed, _river, landscape)
	_dykes = DykeLayout.new(world_seed, _river, _coast, landscape)
	_vegetation = VegetationPlacement.new(world_seed, _river, _coast, landscape)
	_wetland_noise.seed = world_seed + WETLAND_SEED_OFFSET
	_wetland_noise.frequency = WETLAND_FREQUENCY
	_clay_noise.seed = world_seed + CLAY_SEED_OFFSET
	_clay_noise.frequency = CLAY_FREQUENCY
	_clay_roll_seed = world_seed + CLAY_ROLL_SEED_OFFSET


## The chunk at `chunk_coords`, or null if it is outside the world bounds.
func generate_chunk(chunk_coords: Vector2i) -> Chunk:
	if not World.is_chunk_in_bounds(chunk_coords):
		return null
	var chunk := Chunk.new(chunk_coords)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var local := Vector2i(x, y)
			var world_pos := Chunk.to_world(chunk_coords, local)
			# Most of what decides a tile depends on how far the river is: sampled once.
			var river_distance := _river_distance(world_pos)
			var terrain := _terrain_from(world_pos, river_distance)
			chunk.set_terrain(local, terrain)
			var object_type := _object_type_from(world_pos, terrain, river_distance)
			if object_type != &"":
				chunk.add_object(WorldObject.new(object_type, world_pos))
	return chunk


## The one place that decides what a world tile is: the river, the creeks, its floodplain, wetland
## and grass, and the foreshore.
func terrain_at(world_pos: Vector2i) -> Tile.Terrain:
	return _terrain_from(world_pos, _river_distance(world_pos))


## `terrain_at`, for a tile `river_distance` from the river (see `_river_distance`).
func _terrain_from(world_pos: Vector2i, river_distance: float) -> Tile.Terrain:
	if _coast.is_within(world_pos, 0.0):
		return _coast.foreshore_terrain(world_pos, river_distance)
	if river_distance < RIVER_HALF_WIDTH:
		return Tile.Terrain.WATER
	var creek_bed := _creeks.bed_at(world_pos)
	if creek_bed != CreekLayout.Bed.NONE:
		return CREEK_TERRAINS[creek_bed]
	if river_distance < RIVER_HALF_WIDTH + FLOODPLAIN_WIDTH:
		return Tile.Terrain.FLOODPLAIN
	if _wetland_noise.get_noise_2d(world_pos.x, world_pos.y) > WETLAND_THRESHOLD:
		return Tile.Terrain.WETLAND
	return Tile.Terrain.GRASS


## The first tile of land in a row, east of the salt marsh (east of the coast line): where the sea
## dyke stands, or a few tiles west of it where the dyke cuts off a narrow bulge of the land or
## runs along a step of the coast (see DykeLayout).
func first_land_x(y: int) -> int:
	return _coast.first_land_x(y)


## How far a tile is from the river's centre line, along y (see RiverLine `distance`).
func _river_distance(world_pos: Vector2i) -> float:
	return _river.distance(world_pos)


## The type of object generated on a tile, or &"" for none. A pure function of the seed, the
## position and the terrain.
func object_type_at(world_pos: Vector2i, terrain: Tile.Terrain) -> StringName:
	return _object_type_from(world_pos, terrain, _river_distance(world_pos))


## `object_type_at`, for a tile `river_distance` from the river (see `_river_distance`). A dyke
## takes its tile. Otherwise only grass has objects, but for the reeds on the banks. A boulder
## covers the tile to its right, which therefore has to be free grass: otherwise there is no
## boulder.
func _object_type_from(
	world_pos: Vector2i, terrain: Tile.Terrain, river_distance: float
) -> StringName:
	if terrain == Tile.Terrain.MUD:
		return WorldObjectTypes.EWER if _coast.is_ewer_at(world_pos, self) else &""
	if _dykes.is_dyke(world_pos, terrain, river_distance, self):
		return WorldObjectTypes.DYKE
	if terrain == Tile.Terrain.FLOODPLAIN or terrain == Tile.Terrain.WETLAND:
		# The way across a ford is kept clear.
		var is_ford_here := terrain == Tile.Terrain.FLOODPLAIN and is_ford(world_pos)
		var has_reeds := not is_ford_here and _vegetation.is_reeds_at(world_pos, terrain, self)
		return WorldObjectTypes.REEDS if has_reeds else &""
	var object_type := _vegetation.rolled_type_at(world_pos, terrain, river_distance, self)
	if object_type != WorldObjectTypes.BOULDER:
		return object_type
	var right := world_pos + Vector2i.RIGHT
	var right_terrain := terrain_at(right)
	if (
		right_terrain == Tile.Terrain.GRASS
		and (
			_vegetation.rolled_type_at(right, Tile.Terrain.GRASS, _river_distance(right), self)
			== &""
		)
		and object_type_at(right, right_terrain) == &""
	):
		return object_type
	return &""


## Whether a floodplain tile is a ford, where a creek runs shallow over its stones (see
## CreekLayout): drawn as a ford, walked like the floodplain. Asked of another tile it may say yes
## where the river's water lies over a creek's ford.
func is_ford(world_pos: Vector2i) -> bool:
	return _creeks.bed_at(world_pos) == CreekLayout.Bed.FORD


## The kind of tree that grows on a tile, whether or not one stands there.
func tree_type_at(world_pos: Vector2i) -> StringName:
	return _vegetation.tree_type_at(world_pos, _river_distance(world_pos), self)


## Whether a tile lies in a wood, from its edge to its core: where the trees stand close.
func is_forest(world_pos: Vector2i) -> bool:
	return _vegetation.is_forest(world_pos)


## Whether a tile is a spot with clay in it (see CLAY_REACH): a pure function of the seed and
## the position. Spots are only where no object is generated, nor the right half of a boulder, so
## the shovel can reach them.
func is_clay_spot(world_pos: Vector2i) -> bool:
	if (
		_clay_noise.get_noise_2dv(Vector2(world_pos)) <= CLAY_CLUSTER_ABOVE
		or PositionHash.unit(world_pos, _clay_roll_seed) >= CLAY_SPOT_CHANCE
		or terrain_at(world_pos) != Tile.Terrain.GRASS
		or object_type_at(world_pos, Tile.Terrain.GRASS) != &""
		or (
			object_type_at(world_pos + Vector2i.LEFT, terrain_at(world_pos + Vector2i.LEFT))
			== WorldObjectTypes.BOULDER
		)
	):
		return false
	# Water and wetland patches are wide, so probing the 8 directions finds them.
	for distance in range(1, CLAY_REACH + 1):
		for direction in WETLAND_PROBE_DIRECTIONS:
			var terrain := terrain_at(world_pos + direction * distance)
			if terrain == Tile.Terrain.WATER or terrain == Tile.Terrain.WETLAND:
				return true
	return false


## Whether wetland lies WETLAND_REACH tiles away in one of the 8 directions.
func is_near_wetland(world_pos: Vector2i) -> bool:
	for direction in WETLAND_PROBE_DIRECTIONS:
		var probe := world_pos + direction * WETLAND_REACH
		# Wetland is where its noise is high, or a creek's source: the noise is the cheap part to
		# ask first, as the probes of the many trees of a wood mostly find neither.
		var is_wet_noise := _wetland_noise.get_noise_2d(probe.x, probe.y) > WETLAND_THRESHOLD
		if (
			(is_wet_noise or _creeks.bed_at(probe) == CreekLayout.Bed.SOURCE)
			and (terrain_at(probe) == Tile.Terrain.WETLAND)
		):
			return true
	return false


## Whether water lies within `reach` tiles in one of the 8 directions.
func is_water_within(world_pos: Vector2i, reach: int) -> bool:
	for distance in range(1, reach + 1):
		for direction in WETLAND_PROBE_DIRECTIONS:
			if terrain_at(world_pos + direction * distance) == Tile.Terrain.WATER:
				return true
	return false


## Whether a tile has a neighbour (of 8) that is not wetland.
func is_wetland_edge(world_pos: Vector2i) -> bool:
	for direction in WETLAND_PROBE_DIRECTIONS:
		if terrain_at(world_pos + direction) != Tile.Terrain.WETLAND:
			return true
	return false
