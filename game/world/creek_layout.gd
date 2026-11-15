class_name CreekLayout
extends RefCounted
## The natural creeks (Bäche), from data/landscape.cfg ([creeks]): a pure function of the seed and
## the tile position. A few small streams come down to the river, and none is a straight line.
##
## The land is cut into bands of `spacing` tiles along x; each band has a creek with the chance
## `chance` (none where it would come near the coast), running from the river north or south (the
## band's roll picks) for a length between `min_length` and `max_length`. Its middle line swings in
## S-bends (a wavelength of about 35 tiles) up to `meander` tiles either side of the band's middle:
## it can never leave its band (see LandscapeRules). Where the line moves more than a tile from one
## row to the next, a row's water spans from its own middle to those of the rows beside it, so the
## water is always joined row to row (tests/test_creeks.gd checks it). It is about two tiles wide,
## a little narrower at the source, which is a small patch of wetland. Fords, a `FORD_ROWS` tall
## stretch of shallow ground in every `ford_spacing` tiles, let a walker cross.

## What a tile is in a creek.
enum Bed { NONE, WATER, FORD, SOURCE }

## How fast the middle line bends along y (a wavelength of about 35 tiles), and how much the
## noise, which seldom gets beyond 0.7, is stretched so the bends reach the full `meander`.
const BEND_FREQUENCY := 0.028
const BEND_GAIN := 1.4
const BEND_SAMPLE_SPACING := 1000.0
const SOURCE_RADIUS := 2.5
const SOURCE_WIDTH := 1.7
const MOUTH_WIDTH := 2.3
const FORD_ROWS := 2.0
## A band whose creek could come nearer than this to the coast line (the wandering coast included)
## has none: a creek must not break the sea dyke or reach the salt marsh.
const COAST_CLEARANCE := 4.0

const BEND_SEED_OFFSET := 26
const ROLL_SEED_OFFSET := 27

var _river: RiverLine
var _bend_noise := FastNoiseLite.new()
var _roll_seed: int
## The numbers of data/landscape.cfg (see there).
var _spacing: float
var _chance: float
var _meander: float
var _min_length: float
var _max_length: float
var _ford_spacing: float
## West of this world x no creek runs: the coast and its margin.
var _first_creek_x: float


func _init(world_seed: int, river: RiverLine, landscape: LandscapeRules) -> void:
	_river = river
	_bend_noise.seed = world_seed + BEND_SEED_OFFSET
	_bend_noise.frequency = BEND_FREQUENCY
	_bend_noise.fractal_octaves = 1
	_roll_seed = world_seed + ROLL_SEED_OFFSET
	_spacing = landscape.value("creeks", "spacing")
	_chance = landscape.value("creeks", "chance")
	_meander = landscape.value("creeks", "meander")
	_min_length = landscape.value("creeks", "min_length")
	_max_length = landscape.value("creeks", "max_length")
	_ford_spacing = landscape.value("creeks", "ford_spacing")
	_first_creek_x = (
		landscape.value("coast", "line_x") + landscape.value("coast", "wander") + COAST_CLEARANCE
	)


## What the tile is in a creek, `Bed.NONE` for most tiles.
func bed_at(world_pos: Vector2i) -> Bed:
	var band := floori(world_pos.x / _spacing)
	if _roll(band, 0) >= _chance:
		return Bed.NONE
	var middle_x := (band + 0.5) * _spacing
	var reach := _meander + SOURCE_RADIUS
	if absf(world_pos.x + 0.5 - middle_x) > reach or middle_x - reach < _first_creek_x:
		return Bed.NONE
	var is_south_of_river := _roll(band, 1) < 0.5
	var length := lerpf(_min_length, _max_length, _roll(band, 2))
	var middle_here := _middle_at(band, middle_x, world_pos.y)
	# Measured at the creek's own column in this row, not the tile's, so a bend does not cut the
	# water apart where the river runs steeply.
	var from_river := world_pos.y - _river.line_y(middle_here)
	# How far the row is from the river along the creek: negative on the other side of the river.
	var along := from_river if is_south_of_river else -from_river
	if along < 0.0 or along > length + SOURCE_RADIUS:
		return Bed.NONE
	var column := world_pos.x + 0.5
	if absf(along - length) < SOURCE_RADIUS and absf(column - middle_here) < SOURCE_RADIUS:
		return Bed.SOURCE
	var width := lerpf(MOUTH_WIDTH, SOURCE_WIDTH, along / length)
	var middle_before := _middle_at(band, middle_x, world_pos.y - 1)
	var middle_after := _middle_at(band, middle_x, world_pos.y + 1)
	var span_from := minf(middle_here, minf(middle_before, middle_after)) - width / 2.0
	var span_to := maxf(middle_here, maxf(middle_before, middle_after)) + width / 2.0
	if along > length or column < span_from or column > span_to:
		return Bed.NONE
	var first_ford := _roll(band, 3) * _ford_spacing
	return Bed.FORD if fposmod(along - first_ford, _ford_spacing) < FORD_ROWS else Bed.WATER


## Where the creek of a band runs in a row: a world x.
func _middle_at(band: int, middle_x: float, y: int) -> float:
	var bend := clampf(
		_bend_noise.get_noise_2d(y, band * BEND_SAMPLE_SPACING) * BEND_GAIN, -1.0, 1.0
	)
	return middle_x + bend * _meander


## A float in [0, 1) from the band and a number saying what it is rolled for.
func _roll(band: int, what: int) -> float:
	return PositionHash.of(Vector2i(band, what), _roll_seed) % 10000 / 10000.0
