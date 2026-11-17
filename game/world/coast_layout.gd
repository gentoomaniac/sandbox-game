class_name CoastLayout
extends RefCounted
## The North Sea in the west (data/landscape.cfg, [coast], [tideways], [warften] and [ewers]):
## a pure function of the seed and the tile position. A coast line runs north to south,
## x = f(y), like the river's centre line: east of it the land, west of it the foreshore, which
## nothing grows on: the salt marsh, then the tidal mud cut by tideways that widen towards the
## open sea, then the sea. The river runs on through the foreshore, widening.
## Out on the salt marsh stands a Warft here and there: a dwelling mound with a pond (Fething) on
## top, ringed by salt marsh, where nobody lives yet. Now and then an Ewer lies on the mud;
## nothing else stands on the foreshore.

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

const COAST_SEED_OFFSET := 13
const FORESHORE_SEED_OFFSET := 14
const TIDEWAY_SEED_OFFSET := 15
const TIDEWAY_START_ROLL_SEED_OFFSET := 16
const WARFT_ROLL_SEED_OFFSET := 17
const EWER_ROLL_SEED_OFFSET := 18

var _river: RiverLine
var _coast_noise := FastNoiseLite.new()
var _foreshore_noise := FastNoiseLite.new()
var _tideway_noise := FastNoiseLite.new()
var _tideway_start_roll_seed: int
var _warft_roll_seed: int
var _ewer_roll_seed: int
## The numbers of data/landscape.cfg (see there).
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


func _init(world_seed: int, river: RiverLine, landscape: LandscapeRules) -> void:
	_river = river
	_coast_noise.seed = world_seed + COAST_SEED_OFFSET
	_coast_noise.frequency = COAST_FREQUENCY
	_foreshore_noise.seed = world_seed + FORESHORE_SEED_OFFSET
	_foreshore_noise.frequency = FORESHORE_FREQUENCY
	_tideway_noise.seed = world_seed + TIDEWAY_SEED_OFFSET
	_tideway_noise.frequency = TIDEWAY_FREQUENCY
	_tideway_start_roll_seed = world_seed + TIDEWAY_START_ROLL_SEED_OFFSET
	_warft_roll_seed = world_seed + WARFT_ROLL_SEED_OFFSET
	_ewer_roll_seed = world_seed + EWER_ROLL_SEED_OFFSET
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


## How far a tile lies east of the coast line, in tiles along x: negative out on the foreshore.
func tiles_east(world_pos: Vector2i) -> float:
	return world_pos.x - line_x(world_pos.y)


## Whether a tile lies less than `distance` tiles east of the coast line, or west of it. Most of
## the world lies further east than the line ever wanders, which is the cheap part to ask first:
## the terrain probes ask it of many tiles.
func is_within(world_pos: Vector2i, distance: float) -> bool:
	return world_pos.x < _coast_x + _coast_wander + distance and tiles_east(world_pos) < distance


## The first tile of land in a row, east of the salt marsh (east of the coast line).
func first_land_x(y: int) -> int:
	return ceili(line_x(y))


## Where the coast line runs in a row.
func line_x(y: float) -> float:
	return _coast_x + _coast_noise.get_noise_1d(y) * _coast_wander


## What a tile of the foreshore is: the river running out, the salt marsh, the tidal mud with its
## tideways, the open sea. Its water is the sea's.
func foreshore_terrain(world_pos: Vector2i, river_distance: float) -> Tile.Terrain:
	var seaward := -tiles_east(world_pos)
	var estuary_half_width := WorldGenerator.RIVER_HALF_WIDTH + seaward * ESTUARY_WIDENING
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
	if PositionHash.unit(Vector2i(band, 0), _warft_roll_seed) >= _warft_chance:
		return Vector2.INF
	var middle_y := (band + 0.5) * _warft_spacing
	var middle := Vector2(line_x(middle_y) - _warft_out, middle_y)
	if _river.distance(Vector2i(middle)) < WARFT_RIVER_CLEARANCE:
		return Vector2.INF
	return middle


## Whether an Ewer lies with its bow end on a tile of the mud: one in every band of `spacing` rows,
## of which `chance` have one, from `out_from` to `out_to` tiles seaward of the coast line, where
## its other tiles are mud too. Most rows have none, which is asked first.
func is_ewer_at(world_pos: Vector2i, generator: WorldGenerator) -> bool:
	var band := floori(world_pos.y / _ewer_spacing)
	var row := floori(
		(band + PositionHash.unit(Vector2i(band, 1), _ewer_roll_seed)) * _ewer_spacing
	)
	if world_pos.y != row or PositionHash.unit(Vector2i(band, 0), _ewer_roll_seed) >= _ewer_chance:
		return false
	var out := lerpf(
		_ewer_out_from, _ewer_out_to, PositionHash.unit(Vector2i(band, 2), _ewer_roll_seed)
	)
	if world_pos.x != floori(line_x(row) - out):
		return false
	var footprint: Vector2i = WorldObjectTypes.TYPES[WorldObjectTypes.EWER]["footprint"]
	for x in range(1, footprint.x):
		if generator.terrain_at(world_pos + Vector2i(x, 0)) != Tile.Terrain.MUD:
			return false
	return true


## Whether a tile of the mud, `out` tiles from the salt marsh, lies in a tideway. Tideway k winds
## along the middle of the band of rows from k * spacing on, and the bands are wide enough for it
## (see LandscapeRules), so only the tideway of the tile's own band can reach it. Some start a
## little way out on the mud rather than at the salt marsh.
func _is_tideway(world_pos: Vector2i, out: float) -> bool:
	var band := floori(world_pos.y / _tideway_spacing)
	var start := PositionHash.unit(Vector2i(band, 0), _tideway_start_roll_seed) * TIDEWAY_LATE_START
	if out < start:
		return false
	var bend := _tideway_noise.get_noise_2d(world_pos.x, band * TIDEWAY_SAMPLE_SPACING)
	var middle := (band + 0.5) * _tideway_spacing + bend * _tideway_meander
	var width := minf(1.0 + (out - start) * _tideway_widening, _tideway_widest)
	return absf(world_pos.y + 0.5 - middle) < width / 2.0
