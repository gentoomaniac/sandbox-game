class_name WorldGenerator
extends RefCounted
## Generates the grassland biome: grass with one winding river running west to east, a few creeks
## to it (with fords), a floodplain band along both banks and wetland patches, with woods
## (broadleaved, with clumps of pine and spruce on the Geest), bushes, rare dead trees and
## scattered stones and boulders on the grass.
##
## The open land is bare: no fields, fences, hedges, walls or ditches are generated in it (those
## come with the villages, and the player digs ditches). The only work of men in it is the dykes
## (data/landscape.cfg), along the floodplain's edge and the coast.
##
## In the west lies the North Sea (data/landscape.cfg, [coast] and [tideways]). A coast line runs
## north to south, x = f(y), like the river's centre line: east of it the land, whose first tiles
## carry the sea dyke and whose marsh reaches inland from it as from the river; west of it the
## foreshore, which nothing grows on: the salt marsh, then the tidal mud cut by tideways that
## widen towards the open sea, then the sea. The river runs on through the foreshore, widening.
## Out on the salt marsh stands a Warft here and there ([warften]): a dwelling mound with a pond
## (Fething) on top, ringed by salt marsh, where nobody lives yet. Now and then an Ewer lies on the
## mud ([ewers]); nothing else stands on the foreshore.
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

## Clay spots are grass tiles with water (the river) or wetland within CLAY_REACH
## tiles, in the clusters where the clay noise is above CLAY_CLUSTER_ABOVE, of which
## CLAY_SPOT_CHANCE are spots. A grass tile is as far as 3 tiles from the river's water (the
## floodplain lies between).
const CLAY_REACH := 5
const CLAY_CLUSTER_ABOVE := 0.25
const CLAY_SPOT_CHANCE := 0.5

## How much wider the river grows per tile it runs out into the foreshore: an estuary.
const ESTUARY_WIDENING := 0.08
## How far (as a share of `flats_width`) the edge of the open sea wanders in and out.
const SEA_EDGE_WANDER := 0.3
## How far out on the mud a tideway may start, at most, rather than at the salt marsh.
const TIDEWAY_LATE_START := 24.0
## How many tiles of mud a tideway leaves between itself and the river running out: if they met,
## mud between them could be cut off from the land.
const TIDEWAY_RIVER_CLEARANCE := 3.0
## A Warft is an oval this many tiles from its middle to its edge, east-west and north-south, in a
## ring of salt marsh that reaches this many times as far.
const WARFT_RADII := Vector2(5.5, 4.0)
const WARFT_SALT_MARSH_RING := 1.7
## A Warft keeps this far from the river's centre line, in tiles.
const WARFT_RIVER_CLEARANCE := 30.0

## How far a dyke's tile can lie past the edge of the land it runs along (the coast line, the
## floodplain's edge): the edge steps at most 2 tiles from one row to the next (from one column
## to the next for the river), and the dyke takes the tiles along a step and cuts off a narrow
## bulge (see `_is_on_edge_line`), which together is less than this.
const DYKE_LINE_REACH := 8.0
## A tile further than this from the river's centre line can't carry a river dyke.
const DYKE_PROBE_DISTANCE := RIVER_HALF_WIDTH + FLOODPLAIN_WIDTH + DYKE_LINE_REACH
## The places along an edge that decide whether a tile is on its dyke (see `_is_on_edge_line`):
## this many either side of its own.
const EDGE_LINE_SPAN := 3

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
## The dyke noise picks the stretches of the floodplain's edge that have a dyke. Two octaves only:
## more add small wobbles, which near the threshold cut a stretch into pieces a few tiles long.
const DYKE_FREQUENCY := 0.01
const DYKE_OCTAVES := 2
## The coast line's wandering, and the foreshore's (the salt marsh's width, the sea's edge), along
## y; how fast a tideway bends, along x.
const COAST_FREQUENCY := 0.006
const FORESHORE_FREQUENCY := 0.03
const TIDEWAY_FREQUENCY := 0.035
## The foreshore noise is sampled this far along y for the sea's edge, so it does not follow the
## salt marsh's width.
const SEA_EDGE_SAMPLE_OFFSET := 5000.0
## Each tideway bends by the tideway noise sampled this far apart along y.
const TIDEWAY_SAMPLE_SPACING := 1000.0

## Offsets the wetland seed so it is independent of the river noise.
const WETLAND_SEED_OFFSET := 1
const COMPOSITION_SEED_OFFSET := 4
const GRASS_SEED_OFFSET := 6
const CLAY_SEED_OFFSET := 7
const DYKE_SEED_OFFSET := 11
const COAST_SEED_OFFSET := 13
const FORESHORE_SEED_OFFSET := 14
const TIDEWAY_SEED_OFFSET := 15
## Offsets the per-tile object rolls from the noise seeds: one decides the kind of object,
## the other which variety of tree or bush.
const OBJECT_ROLL_SEED_OFFSET := 3
const VARIETY_ROLL_SEED_OFFSET := 5
const GRASS_ROLL_SEED_OFFSET := 8
const CLAY_ROLL_SEED_OFFSET := 9
const REED_ROLL_SEED_OFFSET := 10
const TIDEWAY_START_ROLL_SEED_OFFSET := 16
const WARFT_ROLL_SEED_OFFSET := 17
const EWER_ROLL_SEED_OFFSET := 18

var _river: RiverLine
var _creeks: CreekLayout
var _wetland_noise := FastNoiseLite.new()
var _composition_noise := FastNoiseLite.new()
var _grass_noise := FastNoiseLite.new()
var _clay_noise := FastNoiseLite.new()
var _dyke_noise := FastNoiseLite.new()
var _coast_noise := FastNoiseLite.new()
var _foreshore_noise := FastNoiseLite.new()
var _tideway_noise := FastNoiseLite.new()
var _woods: WoodLayout
var _object_roll_seed: int
var _variety_roll_seed: int
var _grass_roll_seed: int
var _clay_roll_seed: int
var _reed_roll_seed: int
var _tideway_start_roll_seed: int
var _warft_roll_seed: int
var _ewer_roll_seed: int
## The numbers of data/landscape.cfg (see there).
var _marsh_reach: float
var _dyke_above: float
var _coast_x: float
var _coast_wander: float
var _salt_marsh_width: float
var _salt_marsh_wander: float
var _flats_width: float
var _tideway_spacing: float
var _tideway_meander: float
var _tideway_widening: float
var _tideway_widest: float
var _warft_spacing: float
var _warft_chance: float
var _warft_out: float
var _ewer_spacing: float
var _ewer_chance: float
var _ewer_out_from: float
var _ewer_out_to: float


func _init(world_seed: int, landscape := LandscapeRules.default_rules()) -> void:
	_river = RiverLine.new(world_seed)
	_creeks = CreekLayout.new(world_seed, _river, landscape)
	_wetland_noise.seed = world_seed + WETLAND_SEED_OFFSET
	_wetland_noise.frequency = WETLAND_FREQUENCY
	_composition_noise.seed = world_seed + COMPOSITION_SEED_OFFSET
	_composition_noise.frequency = COMPOSITION_FREQUENCY
	_grass_noise.seed = world_seed + GRASS_SEED_OFFSET
	_grass_noise.frequency = GRASS_FREQUENCY
	_clay_noise.seed = world_seed + CLAY_SEED_OFFSET
	_clay_noise.frequency = CLAY_FREQUENCY
	_dyke_noise.seed = world_seed + DYKE_SEED_OFFSET
	_dyke_noise.frequency = DYKE_FREQUENCY
	_dyke_noise.fractal_octaves = DYKE_OCTAVES
	_coast_noise.seed = world_seed + COAST_SEED_OFFSET
	_coast_noise.frequency = COAST_FREQUENCY
	_foreshore_noise.seed = world_seed + FORESHORE_SEED_OFFSET
	_foreshore_noise.frequency = FORESHORE_FREQUENCY
	_tideway_noise.seed = world_seed + TIDEWAY_SEED_OFFSET
	_tideway_noise.frequency = TIDEWAY_FREQUENCY
	_woods = WoodLayout.new(world_seed, landscape)
	_object_roll_seed = world_seed + OBJECT_ROLL_SEED_OFFSET
	_variety_roll_seed = world_seed + VARIETY_ROLL_SEED_OFFSET
	_grass_roll_seed = world_seed + GRASS_ROLL_SEED_OFFSET
	_clay_roll_seed = world_seed + CLAY_ROLL_SEED_OFFSET
	_reed_roll_seed = world_seed + REED_ROLL_SEED_OFFSET
	_tideway_start_roll_seed = world_seed + TIDEWAY_START_ROLL_SEED_OFFSET
	_warft_roll_seed = world_seed + WARFT_ROLL_SEED_OFFSET
	_ewer_roll_seed = world_seed + EWER_ROLL_SEED_OFFSET
	_marsh_reach = landscape.value("marsh", "reach")
	_dyke_above = landscape.value("dykes", "stretch_above")
	_coast_x = landscape.value("coast", "line_x")
	_coast_wander = landscape.value("coast", "wander")
	_salt_marsh_width = landscape.value("coast", "salt_marsh_width")
	_salt_marsh_wander = landscape.value("coast", "salt_marsh_wander")
	_flats_width = landscape.value("coast", "flats_width")
	_tideway_spacing = landscape.value("tideways", "spacing")
	_tideway_meander = landscape.value("tideways", "meander")
	_tideway_widening = landscape.value("tideways", "widening")
	_tideway_widest = landscape.value("tideways", "widest")
	_warft_spacing = landscape.value("warften", "spacing")
	_warft_chance = landscape.value("warften", "chance")
	_warft_out = landscape.value("warften", "out")
	_ewer_spacing = landscape.value("ewers", "spacing")
	_ewer_chance = landscape.value("ewers", "chance")
	_ewer_out_from = landscape.value("ewers", "out_from")
	_ewer_out_to = landscape.value("ewers", "out_to")


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
	if _is_within_coast(world_pos, 0.0):
		return _foreshore_terrain(world_pos, -_coast_distance(world_pos), river_distance)
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


## How far a tile is from the river's centre line, along y (see RiverLine `distance`).
func _river_distance(world_pos: Vector2i) -> float:
	return _river.distance(world_pos)


## How far a tile lies east of the coast line, in tiles along x: negative out on the foreshore.
func _coast_distance(world_pos: Vector2i) -> float:
	return world_pos.x - _coast_line_x(world_pos.y)


## Whether a tile lies less than `distance` tiles east of the coast line, or west of it. Most of
## the world lies further east than the line ever wanders, which is the cheap part to ask first:
## the terrain probes ask it of many tiles.
func _is_within_coast(world_pos: Vector2i, distance: float) -> bool:
	return (
		world_pos.x < _coast_x + _coast_wander + distance and _coast_distance(world_pos) < distance
	)


## The first tile of land in a row, east of the salt marsh (east of the coast line): where the sea
## dyke stands, or a few tiles west of it where the dyke cuts off a narrow bulge of the land or
## runs along a step of the coast (see `_is_on_edge_line`).
func first_land_x(y: int) -> int:
	return ceili(_coast_line_x(y))


## Where the coast line runs in a row.
func _coast_line_x(y: float) -> float:
	return _coast_x + _coast_noise.get_noise_1d(y) * _coast_wander


## The foreshore `seaward` tiles out from the coast line: the river running out, the salt marsh,
## the tidal mud with its tideways, the open sea. Its water is the sea's.
func _foreshore_terrain(world_pos: Vector2i, seaward: float, river_distance: float) -> Tile.Terrain:
	var estuary_half_width := RIVER_HALF_WIDTH + seaward * ESTUARY_WIDENING
	if river_distance < estuary_half_width:
		return Tile.Terrain.SEA
	# How far out a tile is from a Warft's middle: 1 at its edge (INF where there is none).
	var from_warft := Vector2(world_pos) + Vector2(0.5, 0.5) - _warft_middle(world_pos.y)
	var warft_reach := (from_warft / WARFT_RADII).length()
	if warft_reach < 1.0:
		var is_fething := absf(from_warft.x) < 1.0 and absf(from_warft.y) < 1.0
		return Tile.Terrain.WATER if is_fething else Tile.Terrain.WARFT
	var salt_marsh_width := (
		_salt_marsh_width + _foreshore_noise.get_noise_1d(world_pos.y) * _salt_marsh_wander
	)
	if seaward < salt_marsh_width or warft_reach < WARFT_SALT_MARSH_RING:
		return Tile.Terrain.SALT_MARSH
	var out := seaward - salt_marsh_width
	var sea_wander := _foreshore_noise.get_noise_1d(world_pos.y + SEA_EDGE_SAMPLE_OFFSET)
	if out > _flats_width * (1.0 + sea_wander * SEA_EDGE_WANDER):
		return Tile.Terrain.SEA
	var is_clear_of_the_river := river_distance >= estuary_half_width + TIDEWAY_RIVER_CLEARANCE
	if is_clear_of_the_river and _is_tideway(world_pos, out):
		return Tile.Terrain.SEA
	return Tile.Terrain.MUD


## The middle of the Warft in the band of rows of `y` (one band every `spacing` rows, of which
## `chance` have one), `out` tiles seaward of the coast line, or Vector2.INF if it has none, as
## where the river runs out.
func _warft_middle(y: int) -> Vector2:
	var band := floori(y / _warft_spacing)
	if _roll(Vector2i(band, 0), _warft_roll_seed) >= _warft_chance:
		return Vector2.INF
	var middle_y := (band + 0.5) * _warft_spacing
	var middle := Vector2(_coast_line_x(middle_y) - _warft_out, middle_y)
	if _river_distance(Vector2i(middle)) < WARFT_RIVER_CLEARANCE:
		return Vector2.INF
	return middle


## Whether an Ewer lies with its bow end on a tile of the mud: one in every band of `spacing` rows,
## of which `chance` have one, from `out_from` to `out_to` tiles seaward of the coast line, where
## its other tiles are mud too. Most rows have none, which is asked first.
func _is_ewer_at(world_pos: Vector2i) -> bool:
	var band := floori(world_pos.y / _ewer_spacing)
	var row := floori((band + _roll(Vector2i(band, 1), _ewer_roll_seed)) * _ewer_spacing)
	if world_pos.y != row or _roll(Vector2i(band, 0), _ewer_roll_seed) >= _ewer_chance:
		return false
	var out := lerpf(_ewer_out_from, _ewer_out_to, _roll(Vector2i(band, 2), _ewer_roll_seed))
	if world_pos.x != floori(_coast_line_x(row) - out):
		return false
	var footprint: Vector2i = WorldObjectTypes.TYPES[WorldObjectTypes.EWER]["footprint"]
	for x in range(1, footprint.x):
		if terrain_at(world_pos + Vector2i(x, 0)) != Tile.Terrain.MUD:
			return false
	return true


## Whether a tile of the mud, `out` tiles from the salt marsh, lies in a tideway. Tideway k winds
## along the middle of the band of rows from k * spacing on, and the bands are wide enough for it
## (see LandscapeRules), so only the tideway of the tile's own band can reach it. Some start a
## little way out on the mud rather than at the salt marsh.
func _is_tideway(world_pos: Vector2i, out: float) -> bool:
	var band := floori(world_pos.y / _tideway_spacing)
	var start := _roll(Vector2i(band, 0), _tideway_start_roll_seed) * TIDEWAY_LATE_START
	if out < start:
		return false
	var bend := _tideway_noise.get_noise_2d(world_pos.x, band * TIDEWAY_SAMPLE_SPACING)
	var middle := (band + 0.5) * _tideway_spacing + bend * _tideway_meander
	var width := minf(1.0 + (out - start) * _tideway_widening, _tideway_widest)
	return absf(world_pos.y + 0.5 - middle) < width / 2.0


## Whether a tile is in the marsh: the low land along the floodplain and behind the sea dyke, as
## far as its reach.
func _is_marsh(world_pos: Vector2i, river_distance: float) -> bool:
	return (
		river_distance < RIVER_HALF_WIDTH + FLOODPLAIN_WIDTH + _marsh_reach
		or _is_within_coast(world_pos, _marsh_reach)
	)


## Whether a tile of this natural terrain has a dyke: by the sea or along the river.
func _is_dyke(world_pos: Vector2i, natural: Tile.Terrain, river_distance: float) -> bool:
	return _is_sea_dyke(world_pos, natural) or _is_river_dyke(world_pos, natural, river_distance)


## Whether a tile has the sea dyke: land (the floodplain too, where the river runs out) on the
## line along the coast (see `_is_on_edge_line`), but for the river.
func _is_sea_dyke(world_pos: Vector2i, natural: Tile.Terrain) -> bool:
	if (
		natural != Tile.Terrain.GRASS
		and natural != Tile.Terrain.WETLAND
		and natural != Tile.Terrain.FLOODPLAIN
	):
		return false
	# The cheap part first: most tiles lie further east.
	if not _is_within_coast(world_pos, DYKE_LINE_REACH):
		return false
	return _is_on_edge_line(world_pos.y, world_pos.x, first_land_x)


## Whether a tile of this natural terrain has a river dyke: land on the line along the edge of the
## floodplain (see `_is_on_edge_line`), north or south of the river, in a column of a stretch the
## dyke noise picks there. A whole column is in or out, so a stretch begins and ends cleanly, on
## a tile joined on one side. Where a creek cuts the line, a tile left on its own between its
## water has none.
func _is_river_dyke(world_pos: Vector2i, natural: Tile.Terrain, river_distance: float) -> bool:
	if not _is_on_river_dyke_line(world_pos, natural, river_distance):
		return false
	for side in World.CONNECTION_SIDES:
		var neighbour := world_pos + side
		var neighbour_distance := _river_distance(neighbour)
		var neighbour_terrain := _terrain_from(neighbour, neighbour_distance)
		if _is_on_river_dyke_line(neighbour, neighbour_terrain, neighbour_distance):
			return true
	return false


## `_is_river_dyke`, but for the tiles left on their own.
func _is_on_river_dyke_line(
	world_pos: Vector2i, natural: Tile.Terrain, river_distance: float
) -> bool:
	if natural != Tile.Terrain.GRASS and natural != Tile.Terrain.WETLAND:
		return false
	if river_distance >= DYKE_PROBE_DISTANCE:
		return false
	var is_north := world_pos.y < _river.line_y(world_pos.x)
	# Across the edge into the land: north of the river up, south of it down.
	var edge := _north_land_edge if is_north else _south_land_edge
	var across := -world_pos.y if is_north else world_pos.y
	if not _is_on_edge_line(world_pos.x, across, edge):
		return false
	var edge_place: int = edge.call(world_pos.x)
	var edge_row := -edge_place if is_north else edge_place
	return _dyke_noise.get_noise_2d(world_pos.x, edge_row) > _dyke_above


## The first row of the land north of the floodplain in a column, counted upwards (negated), so
## it grows into the land as `_is_on_edge_line` needs.
func _north_land_edge(x: int) -> int:
	var flood_edge := _river.line_y(x) - _river.widening_at(x) - RIVER_HALF_WIDTH - FLOODPLAIN_WIDTH
	return -floori(flood_edge)


## The first row of the land south of the floodplain in a column.
func _south_land_edge(x: int) -> int:
	var flood_edge := _river.line_y(x) + _river.widening_at(x) + RIVER_HALF_WIDTH + FLOODPLAIN_WIDTH
	return ceili(flood_edge)


## Whether a tile is on the dyke's line along the edge of some land: a thin line of tiles joined
## on their sides, which runs on the diagonal where the edge slants (see LineSlants).
## `edge.call(place)` gives at each place along the edge (a row of the coast, a column of the
## river) the first tile across it that is land, the land lying at greater `across`. The line
## takes that tile at every place and, where the edge steps to the next place, the tiles along the
## step, so it is joined on its sides; a stair of single steps is the line on the diagonal. Before
## that a bulge of the land narrower than 3 places is cut off (an opening, in image terms), as the
## line could only follow it in a block or a spur. Depends on the places EDGE_LINE_SPAN either
## side only, so a tile's dyke is a pure function of the seed and its position.
static func _is_on_edge_line(place: int, across: int, edge: Callable) -> bool:
	var edges: Array[int] = []
	for offset in range(-EDGE_LINE_SPAN, EDGE_LINE_SPAN + 1):
		edges.append(edge.call(place + offset))
	var first := _opened_edge(edges, EDGE_LINE_SPAN)
	if across < first:
		return false
	var step_end := maxi(
		_opened_edge(edges, EDGE_LINE_SPAN - 1), _opened_edge(edges, EDGE_LINE_SPAN + 1)
	)
	return across <= maxi(first, step_end)


## The edge at `edges[index]` with the bulges of the land narrower than 3 places cut off: the least
## of the greatest edge of each run of 3 places around it.
static func _opened_edge(edges: Array[int], index: int) -> int:
	var opened := maxi(edges[index - 2], maxi(edges[index - 1], edges[index]))
	for start in range(index - 1, index + 1):
		opened = mini(opened, maxi(edges[start], maxi(edges[start + 1], edges[start + 2])))
	return opened


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
		return WorldObjectTypes.EWER if _is_ewer_at(world_pos) else &""
	if _is_dyke(world_pos, terrain, river_distance):
		return WorldObjectTypes.DYKE
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
		return _tree_type_at(world_pos, river_distance, _roll(world_pos, _variety_roll_seed))
	var bush_chance := OPEN_BUSH_CHANCE
	if is_wood and not _woods.is_clearing_at(world_pos):
		bush_chance = lerpf(
			WOOD_EDGE_BUSH_CHANCE, WOOD_CORE_BUSH_CHANCE, clampf(wood_depth, 0.0, 1.0)
		)
	# Hashes of the position instead of a shared RNG, so the rolls do not depend on the
	# order chunks are generated in.
	var roll := _roll(world_pos, _object_roll_seed)
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
	var is_tall_grass := _woods.noise_at(world_pos) < MEADOW_BELOW and _is_tall_grass_at(world_pos)
	return WorldObjectTypes.TALL_GRASS if is_tall_grass else &""


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
## the position. Spots are only where no object is generated, nor the right half of a boulder, so
## the shovel can reach them.
func is_clay_spot(world_pos: Vector2i) -> bool:
	if (
		_clay_noise.get_noise_2dv(Vector2(world_pos)) <= CLAY_CLUSTER_ABOVE
		or _roll(world_pos, _clay_roll_seed) >= CLAY_SPOT_CHANCE
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


## A float in [0, 1) from a position hash.
func _roll(world_pos: Vector2i, salt: int) -> float:
	return PositionHash.of(world_pos, salt) % 10000 / 10000.0


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
