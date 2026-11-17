class_name WorldGenerator
extends RefCounted
## Generates the grassland biome: grass with one winding river running west to east, a few creeks
## to it (with fords), a floodplain band along both banks and wetland patches, with woods
## (broadleaved, with clumps of pine and spruce on the Geest), bushes, rare dead trees and
## scattered stones and boulders on the grass.
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

## The woods (see WoodLayout) hold the trees; outside them none stands alone. Bushes are the
## other way round: common at the edge of a wood, rare in its core, and in its clearings and the
## meadows as common as in the open. Chances are per grass tile; one roll per tile decides bush,
## stone, boulder, dead tree or nothing, so a tile never has two objects.
const WOOD_EDGE_BUSH_CHANCE := 0.08
const WOOD_CORE_BUSH_CHANCE := 0.01
const OPEN_BUSH_CHANCE := 0.01
const STONE_CHANCE := 0.012
## A boulder is 2 tiles wide: it needs the tile right of the rolled one to be free grass.
const BOULDER_CHANCE := 0.004
## Dead trees are rare everywhere, and more common with wetland WETLAND_REACH tiles away. They
## are of the kind of the trees around, and HALF_DEAD_SHARE of them are only half dead. The old
## single `dead_tree` is no longer placed (only old saves have it).
const DEAD_TREE_CHANCE := 0.0015
const DEAD_TREE_NEAR_WETLAND_CHANCE := 0.02
const HALF_DEAD_SHARE := 0.4
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

## Which trees a forest has. The woods are broadleaved: in the marsh and by the wetland the
## kinds of wet ground, elsewhere on the Geest those of dry ground, picked by their weights
## below. Pine and spruce were rare here before the heath plantations of the late 18th century,
## so they stand only in clumps on the Geest, where the composition noise is above
## CONIFER_CLUMP_ABOVE; over the next CONIFER_CLUMP_EDGE of noise their share rises to all, so a
## clump has a mixed rim. Of the conifers, this share is Scots pine, the Geest's own, and the
## rest planted spruce.
const CONIFER_CLUMP_ABOVE := 0.3
const CONIFER_CLUMP_EDGE := 0.08
const PINE_SHARE_OF_CONIFERS := 0.65
const MARSH_BROADLEAVES := {
	WorldObjectTypes.OAK: 1.0,
	WorldObjectTypes.BIRCH: 1.0,
	WorldObjectTypes.ALDER: 4.0,
	WorldObjectTypes.WILLOW: 2.0
}
const GEEST_BROADLEAVES := {
	WorldObjectTypes.OAK: 3.0, WorldObjectTypes.BEECH: 4.0, WorldObjectTypes.BIRCH: 2.0
}
## The bush kinds as cumulative shares of the bush roll, in order.
const BUSH_KIND_SHARES := [
	[0.3, WorldObjectTypes.BERRY_BUSH],
	[0.6, WorldObjectTypes.SHRUB],
	[0.8, WorldObjectTypes.FERN_BUSH],
	[1.0, WorldObjectTypes.SAPLING],
]

## Features per tile; lower is larger and smoother.
const WETLAND_FREQUENCY := 0.03
const COMPOSITION_FREQUENCY := 0.012
const GRASS_FREQUENCY := 0.05
const CLAY_FREQUENCY := 0.15
## Offsets the wetland seed so it is independent of the river noise.
const WETLAND_SEED_OFFSET := 1
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
const SNAG_ROLL_SEED_OFFSET := 19

var _river: RiverLine
var _creeks: CreekLayout
var _wetland_noise := FastNoiseLite.new()
var _composition_noise := FastNoiseLite.new()
var _grass_noise := FastNoiseLite.new()
var _clay_noise := FastNoiseLite.new()
var _coast: CoastLayout
var _dykes: DykeLayout
var _woods: WoodLayout
var _object_roll_seed: int
var _variety_roll_seed: int
var _snag_roll_seed: int
var _grass_roll_seed: int
var _clay_roll_seed: int
var _reed_roll_seed: int
## The numbers of data/landscape.cfg (see there).
var _marsh_reach: float


func _init(world_seed: int, landscape := LandscapeRules.default_rules()) -> void:
	_river = RiverLine.new(world_seed)
	_creeks = CreekLayout.new(world_seed, _river, landscape)
	_coast = CoastLayout.new(world_seed, _river, landscape)
	_dykes = DykeLayout.new(world_seed, _river, _coast, landscape)
	_wetland_noise.seed = world_seed + WETLAND_SEED_OFFSET
	_wetland_noise.frequency = WETLAND_FREQUENCY
	_composition_noise.seed = world_seed + COMPOSITION_SEED_OFFSET
	_composition_noise.frequency = COMPOSITION_FREQUENCY
	_grass_noise.seed = world_seed + GRASS_SEED_OFFSET
	_grass_noise.frequency = GRASS_FREQUENCY
	_clay_noise.seed = world_seed + CLAY_SEED_OFFSET
	_clay_noise.frequency = CLAY_FREQUENCY
	_woods = WoodLayout.new(world_seed, landscape)
	_object_roll_seed = world_seed + OBJECT_ROLL_SEED_OFFSET
	_variety_roll_seed = world_seed + VARIETY_ROLL_SEED_OFFSET
	_snag_roll_seed = world_seed + SNAG_ROLL_SEED_OFFSET
	_grass_roll_seed = world_seed + GRASS_ROLL_SEED_OFFSET
	_clay_roll_seed = world_seed + CLAY_ROLL_SEED_OFFSET
	_reed_roll_seed = world_seed + REED_ROLL_SEED_OFFSET
	_marsh_reach = landscape.value("marsh", "reach")


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


## Whether a tile is in the marsh: the low land along the floodplain and behind the sea dyke, as
## far as its reach.
func _is_marsh(world_pos: Vector2i, river_distance: float) -> bool:
	return (
		river_distance < RIVER_HALF_WIDTH + FLOODPLAIN_WIDTH + _marsh_reach
		or _coast.is_within(world_pos, _marsh_reach)
	)


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
		var has_reeds := not is_ford_here and _is_reeds_at(world_pos, terrain)
		return WorldObjectTypes.REEDS if has_reeds else &""
	var object_type := _rolled_type_at(world_pos, terrain, river_distance)
	if object_type != WorldObjectTypes.BOULDER:
		return object_type
	var right := world_pos + Vector2i.RIGHT
	var right_terrain := terrain_at(right)
	if (
		right_terrain == Tile.Terrain.GRASS
		and _rolled_type_at(right, Tile.Terrain.GRASS, _river_distance(right)) == &""
		and object_type_at(right, right_terrain) == &""
	):
		return object_type
	return &""


## What the roll of a tile says, before a boulder is checked for room.
func _rolled_type_at(
	world_pos: Vector2i, terrain: Tile.Terrain, river_distance: float
) -> StringName:
	if terrain != Tile.Terrain.GRASS:
		return &""
	var wood_depth := _wood_depth_at(world_pos)
	var is_wood := wood_depth > 0.0
	if is_wood and _woods.has_tree_at(world_pos, wood_depth):
		return _tree_type_at(
			world_pos, river_distance, PositionHash.unit(world_pos, _variety_roll_seed)
		)
	var bush_chance := OPEN_BUSH_CHANCE
	if is_wood and not _woods.is_clearing_at(world_pos):
		bush_chance = lerpf(
			WOOD_EDGE_BUSH_CHANCE, WOOD_CORE_BUSH_CHANCE, clampf(wood_depth, 0.0, 1.0)
		)
	# Hashes of the position instead of a shared RNG, so the rolls do not depend on the
	# order chunks are generated in.
	var roll := PositionHash.unit(world_pos, _object_roll_seed)
	if roll < bush_chance:
		return _bush_type(PositionHash.unit(world_pos, _variety_roll_seed))
	roll -= bush_chance
	if roll < STONE_CHANCE + BOULDER_CHANCE:
		return WorldObjectTypes.STONE if roll < STONE_CHANCE else WorldObjectTypes.BOULDER
	roll -= STONE_CHANCE + BOULDER_CHANCE
	if (
		roll < DEAD_TREE_NEAR_WETLAND_CHANCE
		and (roll < DEAD_TREE_CHANCE or _is_near_wetland(world_pos))
	):
		return _snag_type_at(world_pos, river_distance)
	var is_tall_grass := _woods.noise_at(world_pos) < MEADOW_BELOW and _is_tall_grass_at(world_pos)
	return WorldObjectTypes.TALL_GRASS if is_tall_grass else &""


## A dead or a half-dead tree of the kind of the trees around (see `_tree_type_at`).
func _snag_type_at(world_pos: Vector2i, river_distance: float) -> StringName:
	var kind := _tree_type_at(
		world_pos, river_distance, PositionHash.unit(world_pos, _variety_roll_seed)
	)
	if PositionHash.unit(world_pos, _snag_roll_seed) < HALF_DEAD_SHARE:
		return WorldObjectSnags.half_dead_type(kind)
	return WorldObjectSnags.dead_type(kind)


## Whether a floodplain tile is a ford, where a creek runs shallow over its stones (see
## CreekLayout): drawn as a ford, walked like the floodplain. Asked of another tile it may say yes
## where the river's water lies over a creek's ford.
func is_ford(world_pos: Vector2i) -> bool:
	return _creeks.bed_at(world_pos) == CreekLayout.Bed.FORD


## Whether a tile lies in a wood, from its edge to its core: where the trees stand close.
func is_forest(world_pos: Vector2i) -> bool:
	return _wood_depth_at(world_pos) > 0.0


## How far into a wood a tile lies (see WoodLayout `depth_at`): negative outside one. There is none
## in the marsh, which is treeless but for what stands by wetland; the marsh edge is pushed about
## by the wood's warp, so it is no straight line along the river.
func _wood_depth_at(world_pos: Vector2i) -> float:
	var warped := _woods.warped(world_pos)
	var depth := _woods.depth_at(warped)
	# The marsh is asked second: most tiles are in no wood, and its river distance costs noise calls.
	if depth > 0.0 and _is_marsh(warped, _river_distance(warped)):
		return -1.0
	return depth


func _is_tall_grass_at(world_pos: Vector2i) -> bool:
	var in_patch := _grass_noise.get_noise_2dv(Vector2(world_pos)) > GRASS_PATCH_ABOVE
	var chance := GRASS_PATCH_CHANCE if in_patch else GRASS_SCATTER_CHANCE
	return PositionHash.unit(world_pos, _grass_roll_seed) < chance


func _is_reeds_at(world_pos: Vector2i, terrain: Tile.Terrain) -> bool:
	# The roll is the cheap part: only a tile that can still pass it is probed for water.
	var roll := PositionHash.unit(world_pos, _reed_roll_seed)
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


## The kind of tree on a tile `river_distance` from the river (see the shares above);
## `variety_roll` in [0, 1).
func _tree_type_at(world_pos: Vector2i, river_distance: float, variety_roll: float) -> StringName:
	# Wet ground: the marsh, and on the Geest the land by the wetland.
	if _is_marsh(world_pos, river_distance) or _is_near_wetland(world_pos):
		return _weighted_pick(MARSH_BROADLEAVES, variety_roll)
	var composition := _composition_noise.get_noise_2dv(Vector2(world_pos))
	var conifer_share := clampf((composition - CONIFER_CLUMP_ABOVE) / CONIFER_CLUMP_EDGE, 0.0, 1.0)
	if variety_roll < conifer_share * PINE_SHARE_OF_CONIFERS:
		return WorldObjectTypes.PINE
	if variety_roll < conifer_share:
		return WorldObjectTypes.SPRUCE
	# The roll left over after the conifers, stretched back to [0, 1).
	return _weighted_pick(GEEST_BROADLEAVES, (variety_roll - conifer_share) / (1.0 - conifer_share))


## The kind a roll in [0, 1) picks from kinds and their weights, each kind as likely as its
## share of the total weight.
static func _weighted_pick(weights: Dictionary, roll: float) -> StringName:
	var total := 0.0
	for kind: StringName in weights:
		total += weights[kind]
	var reached := 0.0
	for kind: StringName in weights:
		reached += weights[kind]
		if roll * total < reached:
			return kind
	# Only reached when float rounding leaves roll * total a hair above the last sum.
	return weights.keys()[-1]


func _bush_type(variety_roll: float) -> StringName:
	for entry: Array in BUSH_KIND_SHARES:
		if variety_roll < entry[0]:
			return entry[1]
	return BUSH_KIND_SHARES[-1][1]


func _is_near_wetland(world_pos: Vector2i) -> bool:
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
