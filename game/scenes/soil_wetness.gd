class_name SoilWetness
extends TileMapLayer
## The brown of tilled soil follows its moisture (see World `moisture_at`): the soil terrain is the
## driest look, and a moister tile gets the whole tile in a darker brown over it, one of LOOKS
## steps, on the plain tile grid, over the soil terrain and under every look overlay and the
## objects. The overlay is cut like the bed: a tile at the edge of a field stops short of the
## terrain's rim, so the field keeps its outline, and the tiles inside show no seams (see
## tools/art/soil_beds.py, which draws the atlas: a row for each step above the driest, a column
## for each of the 47 bed shapes). Where a tile is wetter than a tilled neighbour, its brown runs
## on into the neighbour and fades out there over a few pixels: a fade from the side or the corner
## it is at, drawn over the drier tile in a layer of its own for each side and corner (see `fades`
## and the fade atlas of tools/art/soil_beds.py). It follows the world's moisture and tilling
## signals, so it needs nothing from chunk streaming: tilled tiles are drawn wherever they are.
## Soil that snow lies on (see `show_world`) is not drawn and has no fades. After an hour of rain
## the soil's surface is wet: it looks a step wetter than its moisture until a dry hour has passed
## (see `refresh_looks`), so the rain shows on the soil at once.

const TEXTURE_PATH := "res://assets/soil_wet.png"
const FADE_TEXTURE_PATH := "res://assets/soil_fade.png"
const TILE_SIZE := TerrainTileset.TILE_SIZE
## The moisture from which soil looks like each step after the driest, the first of LOOKS. Fresh
## soil (the default moisture of data/crops.cfg) is on the second step; a dry day dries it by one
## step or a little more (data/crops.cfg), so soaked soil is dry again in about three days.
const LOOK_FROM: Array[float] = [0.25, 0.5, 0.75]
const LOOKS := 4
## The rain of an hour (see Weather.rain_in_hour) from which the soil's surface is wet after it.
const RAIN_WETS_SURFACE_FROM := 0.1
## A frame spends this long at the most on drawing the soil again after an hour has passed.
const REFRESH_BUDGET_USEC := 1500
## The neighbours of a tile as bits of its bed shape, as in tools/art/soil_beds.py.
const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const NORTH_EAST := 16
const SOUTH_EAST := 32
const SOUTH_WEST := 64
const NORTH_WEST := 128
const NEIGHBOUR_OFFSETS := {
	NORTH: Vector2i(0, -1),
	EAST: Vector2i(1, 0),
	SOUTH: Vector2i(0, 1),
	WEST: Vector2i(-1, 0),
	NORTH_EAST: Vector2i(1, -1),
	SOUTH_EAST: Vector2i(1, 1),
	SOUTH_WEST: Vector2i(-1, 1),
	NORTH_WEST: Vector2i(-1, -1),
}
const CORNER_SIDES := {
	NORTH_EAST: NORTH | EAST,
	SOUTH_EAST: SOUTH | EAST,
	SOUTH_WEST: SOUTH | WEST,
	NORTH_WEST: NORTH | WEST,
}

## The sides and the corners a fade comes from, in the order of the fade atlas: a column for each
## side and each pair of cuts at its ends (see FADE_ENDS), then one for each corner.
const SIDES: Array[int] = [NORTH, EAST, SOUTH, WEST]
const CORNERS: Array[int] = [NORTH_EAST, SOUTH_EAST, SOUTH_WEST, NORTH_WEST]
## The two ends of a fade along each side: the side across it there and the corner between them.
## The fade is cut to the bed at each end in one of 3 ways: the side across is not tilled, it is
## but the corner is not, or both are.
const FADE_ENDS := {
	NORTH: [[WEST, NORTH_WEST], [EAST, NORTH_EAST]],
	EAST: [[NORTH, NORTH_EAST], [SOUTH, SOUTH_EAST]],
	SOUTH: [[WEST, SOUTH_WEST], [EAST, SOUTH_EAST]],
	WEST: [[NORTH, NORTH_WEST], [SOUTH, SOUTH_WEST]],
}
const END_CUTS := 3
const WET_SOURCE := 0
const FADE_SOURCE := 1
const NO_TILE := Vector2i(-1, -1)

## The column of the atlas of each bed shape (see `bed_shape`).
static var _columns := _bed_columns()

## The layers of the fades over the tiles, by the side or corner they come from.
var _fade_layers: Dictionary[int, TileMapLayer] = {}
var _world: World
var _is_covered: Callable
var _chunks_to_refresh: Array[Vector2i] = []
var _next_chunk_to_refresh := 0
var _tiles_to_refresh: Array[Vector2i] = []
var _next_tile_to_refresh := 0
var _is_surface_wet := false


func _init() -> void:
	name = "SoilWetness"
	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	_add_source(WET_SOURCE, TEXTURE_PATH, _columns.size(), LOOKS - 1)
	_add_source(
		FADE_SOURCE,
		FADE_TEXTURE_PATH,
		SIDES.size() * END_CUTS * END_CUTS + CORNERS.size(),
		_fade_row(LOOKS - 1, LOOKS - 2) + 1
	)
	for direction: int in SIDES + CORNERS:
		var layer := TileMapLayer.new()
		layer.tile_set = tile_set
		add_child(layer)
		_fade_layers[direction] = layer


## Draws the world's tilled soil and follows it from now on. `is_covered` tells for a world tile
## whether snow covers it, and then it is left out; call `redraw_tile` when that changes.
func show_world(world: World, is_covered := func(_pos: Vector2i) -> bool: return false) -> void:
	_world = world
	_is_covered = is_covered
	_world.soil_moisture_changed.connect(_draw_surroundings)
	_world.tile_changed.connect(_draw_surroundings)
	for pos in _world.tilled_tiles():
		_draw_tile(pos)


## Shows the soil of the chosen art set (see ArtSet).
func show_art_set() -> void:
	var source: TileSetAtlasSource = tile_set.get_source(WET_SOURCE)
	source.texture = load(ArtSet.path(TEXTURE_PATH))
	var fade_source: TileSetAtlasSource = tile_set.get_source(FADE_SOURCE)
	fade_source.texture = load(ArtSet.path(FADE_TEXTURE_PATH))


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
	for neighbour: int in NEIGHBOUR_OFFSETS:
		if is_tilled_at.call(pos + NEIGHBOUR_OFFSETS[neighbour]):
			shape |= neighbour
	return _without_lone_corners(shape)


## The fades over a tile of step `look` and bed shape `shape`, whose neighbours are of the steps
## `neighbour_looks` (by their bits; a neighbour that is not tilled is of step 0): their tiles in
## the fade atlas, by the side or the corner they come from. A side fades from a wetter neighbour.
## A corner fades only from a wetter neighbour of the bed (with both its sides tilled, else the
## bed's rim lies there), and only when the fades of its sides don't reach as dark.
static func fades(look: int, shape: int, neighbour_looks: Dictionary) -> Dictionary[int, Vector2i]:
	var tiles: Dictionary[int, Vector2i] = {}
	for side_index in SIDES.size():
		var side := SIDES[side_index]
		if neighbour_looks[side] > look:
			var ends: Array = FADE_ENDS[side]
			var column := (
				(side_index * END_CUTS + _end_cut(shape, ends[0])) * END_CUTS
				+ _end_cut(shape, ends[1])
			)
			tiles[side] = Vector2i(column, _fade_row(neighbour_looks[side], look))
	for corner_index in CORNERS.size():
		var corner := CORNERS[corner_index]
		var wetter: int = neighbour_looks[corner]
		if wetter <= look or not shape & corner:
			continue
		var is_covered_by_sides := false
		for side in SIDES:
			if side & CORNER_SIDES[corner] and neighbour_looks[side] >= wetter:
				is_covered_by_sides = true
		if not is_covered_by_sides:
			tiles[corner] = Vector2i(
				SIDES.size() * END_CUTS * END_CUTS + corner_index, _fade_row(wetter, look)
			)
	return tiles


## The tile of the fade atlas drawn over a tile from its side or corner `direction` (see `fades`),
## or NO_TILE.
func fade_at(world_pos: Vector2i, direction: int) -> Vector2i:
	return _fade_layers[direction].get_cell_atlas_coords(world_pos)


## How many tiles are drawn moister than the driest look. The marks stay wherever the soil is,
## loaded chunks or not, so this is part of what the world view keeps resident.
func mark_count() -> int:
	return get_used_cells().size()


## Draws the soil of the chunks again, in the order given, a few tiles every frame: those that
## now have another step of wetness than the one drawn. The weather wets and dries the soil by
## the hour, and the world tells nothing of it (see SoilMoisture). `last_hour_rain` is the rain
## of the hour that has just ended, which wets the soil's surface. Chunks still waiting from
## before are dropped: these are newer.
func refresh_looks(chunks: Array[Vector2i], last_hour_rain := 0.0) -> void:
	_is_surface_wet = last_hour_rain >= RAIN_WETS_SURFACE_FROM
	_chunks_to_refresh = chunks
	_next_chunk_to_refresh = 0
	_tiles_to_refresh = []
	_next_tile_to_refresh = 0


func _process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	while true:
		if _next_tile_to_refresh >= _tiles_to_refresh.size():
			if _next_chunk_to_refresh >= _chunks_to_refresh.size():
				return
			_tiles_to_refresh = _world.tilled_tiles_in_chunk(
				_chunks_to_refresh[_next_chunk_to_refresh]
			)
			_next_chunk_to_refresh += 1
			_next_tile_to_refresh = 0
			continue
		_draw_tile(_tiles_to_refresh[_next_tile_to_refresh])
		_next_tile_to_refresh += 1
		if Time.get_ticks_usec() - started > REFRESH_BUDGET_USEC:
			return


## Draws one tile again, and the fades around it.
func redraw_tile(world_pos: Vector2i) -> void:
	_draw_surroundings(world_pos)


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


## The row of the fade atlas of the fade from step `wetter` into step `drier`: the pairs of steps
## ordered by the wetter, then the drier.
@warning_ignore("integer_division")
static func _fade_row(wetter: int, drier: int) -> int:
	return wetter * (wetter - 1) / 2 + drier


## How a fade along a side is cut to the bed at an end (see FADE_ENDS): 0 where the side across is
## not tilled, 1 where it is but the corner is not, 2 where both are.
static func _end_cut(shape: int, end: Array) -> int:
	var across: int = end[0]
	var corner: int = end[1]
	if shape & corner:
		return 2
	return 1 if shape & across else 0


## Shows a tile of a texture (see `_add_source`) on a cell of a layer, or empties the cell for
## NO_TILE, unless it shows that already: the hourly refresh draws every tile anew.
static func _show_cell(layer: TileMapLayer, pos: Vector2i, source: int, coords: Vector2i) -> void:
	if layer.get_cell_atlas_coords(pos) != coords:
		layer.set_cell(pos, source, coords)


func _add_source(source_id: int, texture_path: String, columns: int, rows: int) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load(ArtSet.path(texture_path))
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, source_id)
	for column in columns:
		for row in rows:
			source.create_tile(Vector2i(column, row))


## A tile and its neighbours again: the shape of their beds and their fades changed with it.
func _draw_surroundings(world_pos: Vector2i) -> void:
	_draw_tile(world_pos)
	for offset: Vector2i in NEIGHBOUR_OFFSETS.values():
		_draw_tile(world_pos + offset)


func _is_wettable(world_pos: Vector2i) -> bool:
	return _world.is_tilled(world_pos) and not _is_covered.call(world_pos)


func _look_at(world_pos: Vector2i) -> int:
	if not _is_wettable(world_pos):
		return 0
	var look := look_for(_world.moisture_at(world_pos))
	return mini(look + 1, LOOKS - 1) if _is_surface_wet else look


func _draw_tile(world_pos: Vector2i) -> void:
	var wet_tile := NO_TILE
	var fade_tiles: Dictionary[int, Vector2i] = {}
	if _is_wettable(world_pos):
		var look := _look_at(world_pos)
		var shape := bed_shape(_world.is_tilled, world_pos)
		if look > 0:
			wet_tile = Vector2i(_columns[shape], look - 1)
		var neighbour_looks := {}
		var is_alike := true
		for neighbour: int in NEIGHBOUR_OFFSETS:
			var neighbour_look := _look_at(world_pos + NEIGHBOUR_OFFSETS[neighbour])
			neighbour_looks[neighbour] = neighbour_look
			is_alike = is_alike and neighbour_look == look
		# Most tiles are as wet as all around them: they have no fades.
		if not is_alike:
			fade_tiles = fades(look, shape, neighbour_looks)
	_show_cell(self, world_pos, WET_SOURCE, wet_tile)
	for direction: int in _fade_layers:
		_show_cell(
			_fade_layers[direction], world_pos, FADE_SOURCE, fade_tiles.get(direction, NO_TILE)
		)
