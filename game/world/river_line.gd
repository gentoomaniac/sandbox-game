class_name RiverLine
extends RefCounted
## The river's centre line y = f(x), a pure function of the seed. It is a centre line rather than
## a noise isoline: an isoline can fade out or leave isolated pools, but this one is always
## continuous and the distance from it is exact.
##
## Two noises bend it: a slow one swings it up to RIVER_MEANDER_AMPLITUDE tiles north and south of
## y = 0, a finer one adds the small bends of a river that winds. Both use two octaves only: more
## add kinks, and a lowland river has smooth, rounded meanders. A third makes it wider and
## narrower along its way, up to MAX_WIDENING tiles on each bank.

## How far (in tiles) the centre line wanders north and south of y = 0.
const MEANDER_AMPLITUDE := 90.0
## The small bends: how far they push the line, and how fast they change along x.
const BEND_AMPLITUDE := 5.0
const BEND_FREQUENCY := 0.012
## How much wider than its plain width the river gets at most, per bank, and how slowly.
const MAX_WIDENING := 2.0
const WIDENING_FREQUENCY := 0.01
const MEANDER_FREQUENCY := 0.003
const SMOOTH_OCTAVES := 2

const BEND_SEED_OFFSET := 24
const WIDENING_SEED_OFFSET := 25

var _meander_noise := FastNoiseLite.new()
var _bend_noise := FastNoiseLite.new()
var _widening_noise := FastNoiseLite.new()


func _init(world_seed: int) -> void:
	_meander_noise.seed = world_seed
	_meander_noise.frequency = MEANDER_FREQUENCY
	_meander_noise.fractal_octaves = SMOOTH_OCTAVES
	_bend_noise.seed = world_seed + BEND_SEED_OFFSET
	_bend_noise.frequency = BEND_FREQUENCY
	_bend_noise.fractal_octaves = SMOOTH_OCTAVES
	_widening_noise.seed = world_seed + WIDENING_SEED_OFFSET
	_widening_noise.frequency = WIDENING_FREQUENCY
	_widening_noise.fractal_octaves = 1


## The row of the centre line at column x.
func line_y(x: float) -> float:
	return (
		_meander_noise.get_noise_1d(x) * MEANDER_AMPLITUDE
		+ _bend_noise.get_noise_1d(x) * BEND_AMPLITUDE
	)


## How far a tile is from the centre line along y, less the widening at its column: a wide stretch
## of the river counts as nearer, so the river's half width and the floodplain beside it are the
## same numbers everywhere.
func distance(world_pos: Vector2i) -> float:
	return absf(world_pos.y - line_y(world_pos.x)) - widening_at(world_pos.x)


## How much wider than its plain width the river is at column x, per bank, from 0 to MAX_WIDENING.
func widening_at(x: float) -> float:
	return (_widening_noise.get_noise_1d(x) + 1.0) / 2.0 * MAX_WIDENING
