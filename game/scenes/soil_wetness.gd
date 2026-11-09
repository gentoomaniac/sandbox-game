class_name SoilWetness
extends TileMapLayer
## The brown of tilled soil follows its moisture (see World `moisture_at`): the soil terrain is the
## driest look, and a moister tile gets the whole tile in a darker brown over it, one of LOOKS
## steps, on the plain tile grid, over the soil terrain and under every look overlay and the
## objects. The overlay is cut like the bed: a tile at the edge of a field stops short of the
## terrain's rim, so the field keeps its outline, and the tiles inside show no seams (see
## tools/art/soil_beds.py, which draws the atlas: a row for each step above the driest, a column
## for each of the 47 bed shapes). It follows the world's moisture and tilling signals, so it
## needs nothing from chunk streaming: tilled tiles are drawn wherever they are. Soil that snow
## lies on (see `show_world`) is not drawn.

const TEXTURE_PATH := "res://assets/soil_wet.png"
const TILE_SIZE := TerrainTileset.TILE_SIZE
## The moisture from which soil looks like each step after the driest, the first of LOOKS. Fresh
## soil (the default moisture of data/crops.cfg) is on the second step; a dry day dries it by one
## step or a little more (data/crops.cfg), so soaked soil is dry again in about three days.
const LOOK_FROM: Array[float] = [0.25, 0.5, 0.75]
const LOOKS := 4
## The neighbours of a tile as bits of its bed shape, as in tools/art/soil_beds.py.
const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const NORTH_EAST := 16
const SOUTH_EAST := 32
const SOUTH_WEST := 64
const NORTH_WEST := 128
const NEIGHBOUR_BITS := {
	Vector2i(0, -1): NORTH,
	Vector2i(1, 0): EAST,
	Vector2i(0, 1): SOUTH,
	Vector2i(-1, 0): WEST,
	Vector2i(1, -1): NORTH_EAST,
	Vector2i(1, 1): SOUTH_EAST,
	Vector2i(-1, 1): SOUTH_WEST,
	Vector2i(-1, -1): NORTH_WEST,
}
const CORNER_SIDES := {
	NORTH_EAST: NORTH | EAST,
	SOUTH_EAST: SOUTH | EAST,
	SOUTH_WEST: SOUTH | WEST,
	NORTH_WEST: NORTH | WEST,
}

## The column of the atlas of each bed shape (see `bed_shape`).
static var _columns := _bed_columns()

var _world: World
var _is_covered: Callable


func _init() -> void:
	name = "SoilWetness"
	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = load(ArtSet.path(TEXTURE_PATH))
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, 0)
	for column in _columns.size():
		for row in LOOKS - 1:
			source.create_tile(Vector2i(column, row))


## Draws the world's tilled soil and follows it from now on. `is_covered` tells for a world tile
## whether snow covers it, and then it is left out; call `redraw_tile` when that changes.
func show_world(world: World, is_covered := func(_pos: Vector2i) -> bool: return false) -> void:
	_world = world
	_is_covered = is_covered
	_world.soil_moisture_changed.connect(_draw_tile)
	_world.tile_changed.connect(_draw_surroundings)
	for pos in _world.tilled_tiles():
		_draw_tile(pos)


## Shows the soil of the chosen art set (see ArtSet).
func show_art_set() -> void:
	var source: TileSetAtlasSource = tile_set.get_source(0)
	source.texture = load(ArtSet.path(TEXTURE_PATH))


## The step of the brown for a moisture: 0, the driest, to LOOKS - 1, the wettest.
static func look_for(moisture: float) -> int:
	for look in LOOK_FROM.size():
		if moisture < LOOK_FROM[look]:
			return look
	return LOOKS - 1


## The bed shape of a tile: which of its 8 neighbours are tilled, as bits. A corner counts only
## when both its sides do, as the bed is cut the same whatever lies there.
static func bed_shape(is_tilled_at: Callable, pos: Vector2i) -> int:
	var shape := 0
	for offset: Vector2i in NEIGHBOUR_BITS:
		if is_tilled_at.call(pos + offset):
			shape |= NEIGHBOUR_BITS[offset]
	return _without_lone_corners(shape)


## How many tiles are drawn moister than the driest look. The marks stay wherever the soil is,
## loaded chunks or not, so this is part of what the world view keeps resident.
func mark_count() -> int:
	return get_used_cells().size()


## Draws one tile again.
func redraw_tile(world_pos: Vector2i) -> void:
	_draw_tile(world_pos)


## The column of each bed shape: the shapes in ascending order, as the atlas is drawn.
static func _bed_columns() -> Dictionary[int, int]:
	var shapes := {}
	for neighbours in 256:
		shapes[_without_lone_corners(neighbours)] = true
	var sorted_shapes: Array = shapes.keys()
	sorted_shapes.sort()
	var columns: Dictionary[int, int] = {}
	for column in sorted_shapes.size():
		columns[sorted_shapes[column]] = column
	return columns


static func _without_lone_corners(neighbours: int) -> int:
	for corner: int in CORNER_SIDES:
		if neighbours & CORNER_SIDES[corner] != CORNER_SIDES[corner]:
			neighbours &= ~corner
	return neighbours


## A tile and its neighbours again: the shape of their beds changed with it.
func _draw_surroundings(world_pos: Vector2i) -> void:
	_draw_tile(world_pos)
	for offset: Vector2i in NEIGHBOUR_BITS:
		_draw_tile(world_pos + offset)


func _draw_tile(world_pos: Vector2i) -> void:
	var is_wettable: bool = _world.is_tilled(world_pos) and not _is_covered.call(world_pos)
	var look := look_for(_world.moisture_at(world_pos)) if is_wettable else 0
	if look == 0:
		erase_cell(world_pos)
		return
	var shape := bed_shape(_world.is_tilled, world_pos)
	set_cell(world_pos, 0, Vector2i(_columns[shape], look - 1))
