class_name WorldGenerator
extends RefCounted
## Generates the grassland biome: grass with one meandering river running west to east, a
## floodplain band along both banks and wetland patches, with forests (broadleaved woods, with
## clumps of pine and spruce on the Geest), bushes, rare dead trees and scattered stones and
## boulders on the grass.
##
## Over that natural land lies the worked land of data/landscape.cfg: the fields of a
## FieldLayout, bounded on the dry Geest by Knicks, fieldstone walls and wattle fences, and in the
## marsh (the low land along the river) and on wetland by ditches of water with pollard willows
## and reeds beside them; dykes run along the floodplain's edge. Nothing stands on the gap of a
## boundary, and nothing that blocks the way beside it, so no field is shut in. The probes of the
## natural land (for reeds, dead trees) look at the natural terrain, so the worked land only
## changes the tiles it is on and beside, but for the clay, which is also found by the ditches.
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

## Clay spots are grass tiles with water (the river or a ditch) or wetland within CLAY_REACH
## tiles, in the clusters where the clay noise is above CLAY_CLUSTER_ABOVE, of which
## CLAY_SPOT_CHANCE are spots. A grass tile is as far as 3 tiles from the river's water (the
## floodplain lies between).
const CLAY_REACH := 5
const CLAY_CLUSTER_ABOVE := 0.25
const CLAY_SPOT_CHANCE := 0.5

## A tile further than this from the river's centre line can't be beside the floodplain: a
## tile beside it is at most this much nearer, where the river turns steeply.
const DYKE_PROBE_DISTANCE := RIVER_HALF_WIDTH + FLOODPLAIN_WIDTH + 6.0

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

## Which trees a forest has. The woods are broadleaved: in the marsh the kinds of wet ground, on
## the Geest those of dry ground, picked by their weights below. Pine and spruce were rare here
## before the heath plantations of the late 18th century, so they stand only in clumps on the
## Geest, where the composition noise is above CONIFER_CLUMP_ABOVE; over the next
## CONIFER_CLUMP_EDGE of noise their share rises to all, so a clump has a mixed rim. Of the
## conifers, this share is Scots pine, the Geest's own, and the rest planted spruce.
const CONIFER_CLUMP_ABOVE := 0.3
const CONIFER_CLUMP_EDGE := 0.08
const PINE_SHARE_OF_CONIFERS := 0.65
const MARSH_BROADLEAVES := {WorldObjectTypes.OAK: 1.0}
const GEEST_BROADLEAVES := {WorldObjectTypes.OAK: 1.0}
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
## The dyke noise picks the stretches of the floodplain's edge that have a dyke.
const DYKE_FREQUENCY := 0.01

## Offsets the wetland seed so it is independent of the river noise.
const WETLAND_SEED_OFFSET := 1
const FOREST_SEED_OFFSET := 2
const COMPOSITION_SEED_OFFSET := 4
const GRASS_SEED_OFFSET := 6
const CLAY_SEED_OFFSET := 7
const DYKE_SEED_OFFSET := 11
## Offsets the per-tile object rolls from the noise seeds: one decides the kind of object,
## the other which variety of tree or bush.
const OBJECT_ROLL_SEED_OFFSET := 3
const VARIETY_ROLL_SEED_OFFSET := 5
const GRASS_ROLL_SEED_OFFSET := 8
const CLAY_ROLL_SEED_OFFSET := 9
const REED_ROLL_SEED_OFFSET := 10
const DITCH_SIDE_ROLL_SEED_OFFSET := 12

var _river_noise := FastNoiseLite.new()
var _wetland_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _composition_noise := FastNoiseLite.new()
var _grass_noise := FastNoiseLite.new()
var _clay_noise := FastNoiseLite.new()
var _dyke_noise := FastNoiseLite.new()
var _object_roll_seed: int
var _variety_roll_seed: int
var _grass_roll_seed: int
var _clay_roll_seed: int
var _reed_roll_seed: int
var _ditch_side_roll_seed: int
var _fields: FieldLayout
## The numbers of data/landscape.cfg (see there).
var _marsh_reach: float
var _dyke_above: float
var _willow_chance: float
var _ditch_reeds_chance: float


func _init(world_seed: int, landscape := LandscapeRules.default_rules()) -> void:
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
	_dyke_noise.seed = world_seed + DYKE_SEED_OFFSET
	_dyke_noise.frequency = DYKE_FREQUENCY
	_object_roll_seed = world_seed + OBJECT_ROLL_SEED_OFFSET
	_variety_roll_seed = world_seed + VARIETY_ROLL_SEED_OFFSET
	_grass_roll_seed = world_seed + GRASS_ROLL_SEED_OFFSET
	_clay_roll_seed = world_seed + CLAY_ROLL_SEED_OFFSET
	_reed_roll_seed = world_seed + REED_ROLL_SEED_OFFSET
	_ditch_side_roll_seed = world_seed + DITCH_SIDE_ROLL_SEED_OFFSET
	_fields = FieldLayout.new(world_seed, landscape)
	_marsh_reach = landscape.value("marsh", "reach")
	_dyke_above = landscape.value("dykes", "stretch_above")
	_willow_chance = landscape.value("ditches", "willow_chance")
	_ditch_reeds_chance = landscape.value("ditches", "reeds_chance")


## The chunk at `chunk_coords`, or null if it is outside the world bounds.
func generate_chunk(chunk_coords: Vector2i) -> Chunk:
	if not World.is_chunk_in_bounds(chunk_coords):
		return null
	var chunk := Chunk.new(chunk_coords)
	# Every tile and its sides are asked about.
	_fields.cover(
		Rect2i(Chunk.to_world(chunk_coords, Vector2i.ZERO), Vector2i.ONE * Chunk.CHUNK_SIZE).grow(1)
	)
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


## The one place that decides what a world tile is: the natural terrain, but for the ditches.
func terrain_at(world_pos: Vector2i) -> Tile.Terrain:
	return _terrain_from(world_pos, _river_distance(world_pos))


## `terrain_at`, for a tile `river_distance` from the river (see `_river_distance`).
func _terrain_from(world_pos: Vector2i, river_distance: float) -> Tile.Terrain:
	var terrain := _natural_terrain_from(world_pos, river_distance)
	return Tile.Terrain.WATER if _is_ditch(world_pos, terrain, river_distance) else terrain


## Whether a tile is a ditch: water where the natural land has none.
func is_ditch(world_pos: Vector2i) -> bool:
	# Most tiles are on no boundary: that is the cheap part to ask first.
	var boundary := _fields.boundary_at(world_pos)
	if boundary == &"" or boundary == FieldLayout.GAP:
		return false
	var river_distance := _river_distance(world_pos)
	return _is_ditch(world_pos, _natural_terrain_from(world_pos, river_distance), river_distance)


## The land as nature made it: the river, its floodplain, wetland and grass.
func _natural_terrain_at(world_pos: Vector2i) -> Tile.Terrain:
	return _natural_terrain_from(world_pos, _river_distance(world_pos))


func _natural_terrain_from(world_pos: Vector2i, river_distance: float) -> Tile.Terrain:
	if river_distance < RIVER_HALF_WIDTH:
		return Tile.Terrain.WATER
	if river_distance < RIVER_HALF_WIDTH + FLOODPLAIN_WIDTH:
		return Tile.Terrain.FLOODPLAIN
	if _wetland_noise.get_noise_2d(world_pos.x, world_pos.y) > WETLAND_THRESHOLD:
		return Tile.Terrain.WETLAND
	return Tile.Terrain.GRASS


## How far a tile is from the river's centre line, along y. The river is a centre line
## y = f(x) rather than a noise isoline: an isoline can fade out or leave isolated pools, but
## this one is always continuous and the floodplain distance is exact.
func _river_distance(world_pos: Vector2i) -> float:
	return absf(world_pos.y - _river_noise.get_noise_1d(world_pos.x) * RIVER_MEANDER_AMPLITUDE)


## Whether a tile this far from the river is in the marsh: the low land along the floodplain, as
## wide as its reach.
func _is_marsh(river_distance: float) -> bool:
	return river_distance < RIVER_HALF_WIDTH + FLOODPLAIN_WIDTH + _marsh_reach


## Whether a tile of this natural terrain is a ditch: a field boundary on wetland or in the
## marsh, but for its gap and where a dyke runs.
func _is_ditch(world_pos: Vector2i, natural: Tile.Terrain, river_distance: float) -> bool:
	var boundary := _fields.boundary_at(world_pos)
	if boundary == &"" or boundary == FieldLayout.GAP:
		return false
	var is_wet_land := (
		natural == Tile.Terrain.WETLAND
		or natural == Tile.Terrain.GRASS and _is_marsh(river_distance)
	)
	return is_wet_land and not _is_dyke(world_pos, natural, river_distance)


## Whether a tile of this natural terrain has a dyke: land with the floodplain among the 8 tiles
## around it (so the dyke is a line joined on its sides), on a stretch the dyke noise picks.
func _is_dyke(world_pos: Vector2i, natural: Tile.Terrain, river_distance: float) -> bool:
	if natural != Tile.Terrain.GRASS and natural != Tile.Terrain.WETLAND:
		return false
	if river_distance >= DYKE_PROBE_DISTANCE:
		return false
	if _dyke_noise.get_noise_2dv(Vector2(world_pos)) <= _dyke_above:
		return false
	for direction in WETLAND_PROBE_DIRECTIONS:
		if _natural_terrain_at(world_pos + direction) == Tile.Terrain.FLOODPLAIN:
			return true
	return false


## The type of object generated on a tile, or &"" for none. A pure function of the seed, the
## position and the terrain. A dyke or a field boundary on the Geest (dry grass out of the marsh
## and the forests) takes the tile; nothing stands on the gap of a boundary, and nothing that
## blocks the way beside it.
func object_type_at(world_pos: Vector2i, terrain: Tile.Terrain) -> StringName:
	return _object_type_from(world_pos, terrain, _river_distance(world_pos))


## `object_type_at`, for a tile `river_distance` from the river (see `_river_distance`).
func _object_type_from(
	world_pos: Vector2i, terrain: Tile.Terrain, river_distance: float
) -> StringName:
	if _is_dyke(world_pos, terrain, river_distance):
		return WorldObjectTypes.DYKE
	var boundary := _fields.boundary_at(world_pos)
	if boundary == FieldLayout.GAP:
		return &""
	if boundary != &"" and _is_geest_field(world_pos, terrain, river_distance):
		return boundary
	var object_type := _natural_object_at(world_pos, terrain, river_distance)
	if (
		object_type != &""
		and WorldObjectTypes.TYPES[object_type]["blocks_walking"]
		and _is_beside_gap(world_pos)
	):
		return &""
	return object_type


## Whether a tile is grass of the Geest out of the forests: where the field boundaries are
## hedges, walls and fences.
func _is_geest_field(world_pos: Vector2i, terrain: Tile.Terrain, river_distance: float) -> bool:
	return (
		terrain == Tile.Terrain.GRASS
		and not _is_marsh(river_distance)
		and _forest_noise.get_noise_2dv(Vector2(world_pos)) < FOREST_THRESHOLD
	)


func _is_beside_gap(world_pos: Vector2i) -> bool:
	for side in World.CONNECTION_SIDES:
		if _fields.boundary_at(world_pos + side) == FieldLayout.GAP:
			return true
	return false


## What nature and the ditches put on a tile: only grass has objects, but for the reeds on the
## banks and what stands beside a ditch. A boulder covers the tile to its right, which therefore
## has to be free grass: otherwise there is no boulder.
func _natural_object_at(
	world_pos: Vector2i, terrain: Tile.Terrain, river_distance: float
) -> StringName:
	var by_ditch := _ditch_side_type_at(world_pos, terrain, river_distance)
	if by_ditch != &"":
		return by_ditch
	if terrain == Tile.Terrain.FLOODPLAIN or terrain == Tile.Terrain.WETLAND:
		return WorldObjectTypes.REEDS if _is_reeds_at(world_pos, terrain) else &""
	var object_type := _rolled_type_at(world_pos, terrain, river_distance)
	if object_type != WorldObjectTypes.BOULDER:
		return object_type
	var right := world_pos + Vector2i.RIGHT
	var right_terrain := terrain_at(right)
	if (
		right_terrain == Tile.Terrain.GRASS
		and _rolled_type_at(right, Tile.Terrain.GRASS, _river_distance(right)) == &""
		and object_type_at(right, right_terrain) == &""
		and _fields.boundary_at(right) == &""
		and not _is_beside_gap(right)
	):
		return object_type
	return &""


## A pollard willow or reeds beside a ditch, on wetland or in the marsh, with the chances of
## data/landscape.cfg, or &"".
func _ditch_side_type_at(
	world_pos: Vector2i, terrain: Tile.Terrain, river_distance: float
) -> StringName:
	var is_wet_land := (
		terrain == Tile.Terrain.WETLAND
		or terrain == Tile.Terrain.GRASS and _is_marsh(river_distance)
	)
	if not is_wet_land:
		return &""
	# The roll is the cheap part: only a tile that can still pass it is probed for a ditch.
	var roll := _roll(world_pos, _ditch_side_roll_seed)
	if roll >= _willow_chance + _ditch_reeds_chance or not _is_beside_ditch(world_pos):
		return &""
	return WorldObjectTypes.WILLOW if roll < _willow_chance else WorldObjectTypes.REEDS


func _is_beside_ditch(world_pos: Vector2i) -> bool:
	for side in World.CONNECTION_SIDES:
		if is_ditch(world_pos + side):
			return true
	return false


## What the roll of a tile says, before a boulder is checked for room.
func _rolled_type_at(
	world_pos: Vector2i, terrain: Tile.Terrain, river_distance: float
) -> StringName:
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
		return _tree_type_at(world_pos, river_distance, _roll(world_pos, _variety_roll_seed))
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
			if _natural_terrain_at(world_pos + direction * distance) == Tile.Terrain.WATER:
				return true
	return false


func _is_wetland_edge(world_pos: Vector2i) -> bool:
	for direction in WETLAND_PROBE_DIRECTIONS:
		if _natural_terrain_at(world_pos + direction) != Tile.Terrain.WETLAND:
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
	# Water and wetland patches are wide and ditches long, so probing the 8 directions finds
	# them. The marsh clay by the ditches makes up for the clay the dykes cover.
	for distance in range(1, CLAY_REACH + 1):
		for direction in WETLAND_PROBE_DIRECTIONS:
			var terrain := terrain_at(world_pos + direction * distance)
			if terrain == Tile.Terrain.WATER or terrain == Tile.Terrain.WETLAND:
				return true
	return false


## A float in [0, 1) from a position hash.
func _roll(world_pos: Vector2i, salt: int) -> float:
	return PositionHash.of(world_pos, salt) % 10000 / 10000.0


## The kind of tree on a tile `river_distance` from the river (see the shares above);
## `variety_roll` in [0, 1).
func _tree_type_at(world_pos: Vector2i, river_distance: float, variety_roll: float) -> StringName:
	if _is_marsh(river_distance):
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
	return weights.keys()[-1]


func _bush_type(variety_roll: float) -> StringName:
	for entry: Array in BUSH_KIND_SHARES:
		if variety_roll < entry[0]:
			return entry[1]
	return BUSH_KIND_SHARES[-1][1]


func _is_near_wetland(world_pos: Vector2i) -> bool:
	for direction in WETLAND_PROBE_DIRECTIONS:
		if _natural_terrain_at(world_pos + direction * WETLAND_REACH) == Tile.Terrain.WETLAND:
			return true
	return false
