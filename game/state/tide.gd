class_name Tide
extends RefCounted
## The tide of the North Sea on the tidal mud: high water twice a day, a little later each day. The
## shader of the mud (mud.gdshader) draws the water over a relief of the flats; this class ports
## that relief to say which tiles of mud are under water (see `floods`).

## From one high water to the next, in game minutes: 12 hours 25 minutes.
const PERIOD_MINUTES := 745.0

## The water's level at low and at high water, on the relief's scale (0 to 1). Ported from
## mud.gdshader, which tests/test_tide.gd compares them with.
const LOW_WATER := 0.04
const HIGH_WATER := 1.06
## The relief: broad swells and smaller hollows, in world pixels across.
const SWELL_SIZE := 140.0
const HOLLOW_SIZE := 46.0
const SWELL_SHARE := 0.65
const HOLLOW_SHARE := 0.35
## The multipliers of the integer hash of the relief's grid corners (the shader's `corner_value`).
const HASH_X := 73856093
const HASH_Y := 19349663
const HASH_LAYER := 83492791
const HASH_MIX := 1274126177
const UINT32 := 0xFFFFFFFF
## How many points per side of a tile the relief is looked at to tell whether most of it is under
## water.
const SAMPLES_PER_SIDE := 4
## The most tiles `flood_height` keeps, so that a long walk along the coast does not fill memory.
const MAX_KEPT_TILES := 50000

static var _flood_heights: Dictionary[Vector2i, float] = {}


## How high the water stands at a moment of the game clock (`GameClock.total_minutes`): 1 at
## high water, 0 at low water, rising and falling smoothly in between. The first high water is at
## midnight before day 1.
static func level(total_minutes: float) -> float:
	return 0.5 + 0.5 * cos(TAU * total_minutes / PERIOD_MINUTES)


## The height of the water on the relief's scale at a tide level (see `level`).
static func water_height(tide_level: float) -> float:
	return lerpf(LOW_WATER, HIGH_WATER, tide_level)


## The height of the mud's relief at a point of the world in pixels, from 0 to 1: the water covers
## the point once it stands higher. The dark troughs of the mud's art lie a bit lower in the
## picture; they are a matter of the pixels and not counted here.
static func relief_at(point: Vector2) -> float:
	return (
		SWELL_SHARE * _value_noise(point, SWELL_SIZE, 1)
		+ HOLLOW_SHARE * _value_noise(point, HOLLOW_SIZE, 2)
	)


## Whether the water covers the mud of a tile at a tide level (see `level`): when it covers most of
## the tile's picture, which is what a player sees and where they expect to be able to step.
static func floods(tile: Vector2i, tide_level: float) -> bool:
	return flood_height(tile) < water_height(tide_level)


## The height of the water on the relief's scale from which it covers most of a tile: the middle
## one of the heights of the relief at a grid of points over it. Kept, as the relief is fixed and
## the animals ask at every step.
static func flood_height(tile: Vector2i) -> float:
	if _flood_heights.has(tile):
		return _flood_heights[tile]
	var heights: Array[float] = []
	for y in SAMPLES_PER_SIDE:
		for x in SAMPLES_PER_SIDE:
			var offset := (Vector2(x, y) + Vector2(0.5, 0.5)) / SAMPLES_PER_SIDE
			heights.append(relief_at((Vector2(tile) + offset) * WildlifeRules.TILE_SIZE))
	heights.sort()
	if _flood_heights.size() >= MAX_KEPT_TILES:
		_flood_heights.clear()
	@warning_ignore("integer_division")
	_flood_heights[tile] = heights[heights.size() / 2]
	return _flood_heights[tile]


# A value from 0 to 1 for a corner of the relief's grid, from whole numbers.
static func _corner_value(corner: Vector2i, layer: int) -> float:
	var h := (
		(((corner.x & UINT32) * HASH_X) ^ ((corner.y & UINT32) * HASH_Y) ^ (layer * HASH_LAYER))
		& UINT32
	)
	h = ((h ^ (h >> 13)) * HASH_MIX) & UINT32
	h ^= h >> 16
	return float(h & 65535) / 65535.0


# Smooth noise from 0 to 1, with a value per corner of a grid of `size` pixels.
static func _value_noise(point: Vector2, size: float, layer: int) -> float:
	var scaled := point / size
	var cell := Vector2i(scaled.floor())
	var fraction := scaled - scaled.floor()
	var fx := smoothstep(0.0, 1.0, fraction.x)
	var fy := smoothstep(0.0, 1.0, fraction.y)
	var a := _corner_value(cell, layer)
	var b := _corner_value(cell + Vector2i(1, 0), layer)
	var c := _corner_value(cell + Vector2i(0, 1), layer)
	var d := _corner_value(cell + Vector2i(1, 1), layer)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)
