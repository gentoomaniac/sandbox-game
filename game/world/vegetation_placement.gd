class_name VegetationPlacement
extends RefCounted
## What grows on the grass of the open land, a pure function of the seed and the tile position:
## the woods (see WoodLayout) with their trees, the bushes, stones, boulders and dead trees, the
## tall grass of the meadows and the reeds on the banks. Which tree stands where depends on the
## marsh, the low land along the river and behind the sea dyke.

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
## Dead trees are rare everywhere, and more common with wetland near (see WorldGenerator). They
## are of the kind of the trees around, and HALF_DEAD_SHARE of them are only half dead. The old
## single `dead_tree` is no longer placed (only old saves have it).
const DEAD_TREE_CHANCE := 0.0015
const DEAD_TREE_NEAR_WETLAND_CHANCE := 0.02
const HALF_DEAD_SHARE := 0.4

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
const COMPOSITION_FREQUENCY := 0.012
const GRASS_FREQUENCY := 0.05
const COMPOSITION_SEED_OFFSET := 4
const GRASS_SEED_OFFSET := 6
## Offsets the per-tile object rolls from the noise seeds: one decides the kind of object,
## the other which variety of tree or bush.
const OBJECT_ROLL_SEED_OFFSET := 3
const VARIETY_ROLL_SEED_OFFSET := 5
const GRASS_ROLL_SEED_OFFSET := 8
const REED_ROLL_SEED_OFFSET := 10
const SNAG_ROLL_SEED_OFFSET := 19

var _river: RiverLine
var _coast: CoastLayout
var _woods: WoodLayout
var _composition_noise := FastNoiseLite.new()
var _grass_noise := FastNoiseLite.new()
var _object_roll_seed: int
var _variety_roll_seed: int
var _snag_roll_seed: int
var _grass_roll_seed: int
var _reed_roll_seed: int
## The number of data/landscape.cfg (see there).
var _marsh_reach: float


func _init(
	world_seed: int, river: RiverLine, coast: CoastLayout, landscape: LandscapeRules
) -> void:
	_river = river
	_coast = coast
	_woods = WoodLayout.new(world_seed, landscape)
	_composition_noise.seed = world_seed + COMPOSITION_SEED_OFFSET
	_composition_noise.frequency = COMPOSITION_FREQUENCY
	_grass_noise.seed = world_seed + GRASS_SEED_OFFSET
	_grass_noise.frequency = GRASS_FREQUENCY
	_object_roll_seed = world_seed + OBJECT_ROLL_SEED_OFFSET
	_variety_roll_seed = world_seed + VARIETY_ROLL_SEED_OFFSET
	_snag_roll_seed = world_seed + SNAG_ROLL_SEED_OFFSET
	_grass_roll_seed = world_seed + GRASS_ROLL_SEED_OFFSET
	_reed_roll_seed = world_seed + REED_ROLL_SEED_OFFSET
	_marsh_reach = landscape.value("marsh", "reach")


## Whether a tile lies in a wood, from its edge to its core: where the trees stand close.
func is_forest(world_pos: Vector2i) -> bool:
	return _wood_depth_at(world_pos) > 0.0


## Whether a tile is in the marsh: the low land along the floodplain and behind the sea dyke, as
## far as its reach.
func _is_marsh(world_pos: Vector2i, river_distance: float) -> bool:
	return (
		(
			river_distance
			< WorldGenerator.RIVER_HALF_WIDTH + WorldGenerator.FLOODPLAIN_WIDTH + _marsh_reach
		)
		or _coast.is_within(world_pos, _marsh_reach)
	)


## What the roll of a tile says, before a boulder is checked for room.
func rolled_type_at(
	world_pos: Vector2i, terrain: Tile.Terrain, river_distance: float, generator: WorldGenerator
) -> StringName:
	if terrain != Tile.Terrain.GRASS:
		return &""
	var wood_depth := _wood_depth_at(world_pos)
	var is_wood := wood_depth > 0.0
	if is_wood and _woods.has_tree_at(world_pos, wood_depth):
		return tree_type_at(world_pos, river_distance, generator)
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
		and (roll < DEAD_TREE_CHANCE or generator.is_near_wetland(world_pos))
	):
		return _snag_type_at(world_pos, river_distance, generator)
	var is_tall_grass := _woods.noise_at(world_pos) < MEADOW_BELOW and _is_tall_grass_at(world_pos)
	return WorldObjectTypes.TALL_GRASS if is_tall_grass else &""


## A dead or a half-dead tree of the kind of the trees around (see `tree_type_at`).
func _snag_type_at(
	world_pos: Vector2i, river_distance: float, generator: WorldGenerator
) -> StringName:
	var kind := tree_type_at(world_pos, river_distance, generator)
	if PositionHash.unit(world_pos, _snag_roll_seed) < HALF_DEAD_SHARE:
		return WorldObjectSnags.half_dead_type(kind)
	return WorldObjectSnags.dead_type(kind)


## How far into a wood a tile lies (see WoodLayout `depth_at`): negative outside one. There is none
## in the marsh, which is treeless but for what stands by wetland; the marsh edge is pushed about
## by the wood's warp, so it is no straight line along the river.
func _wood_depth_at(world_pos: Vector2i) -> float:
	var warped := _woods.warped(world_pos)
	var depth := _woods.depth_at(warped)
	# The marsh is asked second: most tiles are in no wood, and its river distance costs noise calls.
	if depth > 0.0 and _is_marsh(warped, _river.distance(warped)):
		return -1.0
	return depth


func _is_tall_grass_at(world_pos: Vector2i) -> bool:
	var in_patch := _grass_noise.get_noise_2dv(Vector2(world_pos)) > GRASS_PATCH_ABOVE
	var chance := GRASS_PATCH_CHANCE if in_patch else GRASS_SCATTER_CHANCE
	return PositionHash.unit(world_pos, _grass_roll_seed) < chance


## Whether reeds stand on a tile of this terrain: floodplain or wetland.
func is_reeds_at(world_pos: Vector2i, terrain: Tile.Terrain, generator: WorldGenerator) -> bool:
	# The roll is the cheap part: only a tile that can still pass it is probed for water.
	var roll := PositionHash.unit(world_pos, _reed_roll_seed)
	if roll >= maxf(REED_STAND_CHANCE, REED_SCATTER_CHANCE):
		return false
	var is_bank := (
		generator.is_wetland_edge(world_pos)
		if terrain == Tile.Terrain.WETLAND
		else generator.is_water_within(world_pos, REEDS_REACH)
	)
	if not is_bank:
		return false
	var in_stand := _grass_noise.get_noise_2dv(Vector2(world_pos)) > REED_STAND_ABOVE
	var chance := REED_STAND_CHANCE if in_stand else REED_SCATTER_CHANCE
	return roll < chance


## The kind of tree on a tile `river_distance` from the river (see the shares above).
func tree_type_at(
	world_pos: Vector2i, river_distance: float, generator: WorldGenerator
) -> StringName:
	var variety_roll := PositionHash.unit(world_pos, _variety_roll_seed)
	# Wet ground: the marsh, and on the Geest the land by the wetland.
	if _is_marsh(world_pos, river_distance) or generator.is_near_wetland(world_pos):
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
