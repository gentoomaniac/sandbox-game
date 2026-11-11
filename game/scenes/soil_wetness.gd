class_name SoilWetness
extends TileMapLayer
## The brown of tilled soil follows its moisture (see World `moisture_at`): the soil terrain is the
## driest look, and a moister tile gets the whole tile in a darker brown over it, one of LOOKS
## steps, on the plain tile grid, over the soil terrain and under every look overlay and the
## objects. The overlay is cut like the bed: a tile at the edge of a field stops short of the
## terrain's rim, so the field keeps its outline, and the tiles inside show no seams (see
## tools/art/soil_beds.py, which draws the atlas: a row for each step above the driest, a column
## for each of the 47 bed shapes). Where a tile is wetter than a tilled neighbour, the line between
## their browns is the edge of a wet patch: it wanders across the tile edge, runs on along the
## patch's edge and rounds off its corners (see `edges` and the edge atlas of
## tools/art/soil_beds.py), drawn in pieces over both tiles, each in a layer of its own. It follows
## the world's moisture and tilling signals, so it needs nothing from chunk streaming: tilled
## tiles are drawn wherever they are. Soil that snow lies on (see `show_world`) is not drawn and
## has no edges. After an hour of rain the soil's surface is wet: it looks a step wetter than its
## moisture until a dry hour has passed (see `refresh_looks`), so the rain shows on the soil at
## once.

const TEXTURE_PATH := "res://assets/soil_wet.png"
const EDGE_TEXTURE_PATH := "res://assets/soil_edge.png"
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

## The sides and the corners of a tile, in the order of the edge atlas: a column for each side and
## each pair of the ways its ends end (see SIDE_ENDS), then one for each corner.
const SIDES: Array[int] = [NORTH, EAST, SOUTH, WEST]
const CORNERS: Array[int] = [NORTH_EAST, SOUTH_EAST, SOUTH_WEST, NORTH_WEST]
## The two ends of each side: the side across it there and the corner between them.
const SIDE_ENDS := {
	NORTH: [[WEST, NORTH_WEST], [EAST, NORTH_EAST]],
	EAST: [[NORTH, NORTH_EAST], [SOUTH, SOUTH_EAST]],
	SOUTH: [[WEST, SOUTH_WEST], [EAST, SOUTH_EAST]],
	WEST: [[NORTH, NORTH_WEST], [SOUTH, SOUTH_WEST]],
}
## How a side's edge ends: at the bed's rim (the tile across is not tilled, or under snow),
## running on into the next tiles (they are as wet as these two), or turning.
const END_RIM := 0
const END_RUNS_ON := 1
const END_TURNS := 2
const END_KINDS := 3
## The wavy line of an edge repeats every this many tiles along a line of the grid.
const PHASES := 4
## The pieces of an edge are stacked, one for each step between its two tiles: at most this many.
const PIECE_SLOTS := LOOKS - 1
const WET_SOURCE := 0
const EDGE_SOURCE := 1
const NO_TILE := Vector2i(-1, -1)

## The column of the atlas of each bed shape (see `bed_shape`).
static var _columns := _bed_columns()

## The layers of the edge pieces over the tiles: for each side and then each corner (as in SIDES
## and CORNERS), PIECE_SLOTS layers, drawn in that order.
var _edge_layers: Array[TileMapLayer] = []
## The tiles that have edge pieces drawn on them.
var _edged_tiles: Dictionary[Vector2i, bool] = {}
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
		EDGE_SOURCE,
		EDGE_TEXTURE_PATH,
		SIDES.size() * END_KINDS * END_KINDS + CORNERS.size(),
		2 * PIECE_SLOTS * PHASES
	)
	for _layer in (SIDES.size() + CORNERS.size()) * PIECE_SLOTS:
		var layer := TileMapLayer.new()
		layer.tile_set = tile_set
		add_child(layer)
		_edge_layers.append(layer)


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
	var edge_source: TileSetAtlasSource = tile_set.get_source(EDGE_SOURCE)
	edge_source.texture = load(ArtSet.path(EDGE_TEXTURE_PATH))


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


## The edge pieces over the tile at `pos` of step `look`, whose neighbours are of the steps
## `neighbour_looks` (by their bits; -1 for one that is not tilled, or under snow): their tiles in
## the edge atlas, by their layer (see `_edge_layers`). Along a side with a wetter neighbour a
## bulge of each step up to it, along one with a drier neighbour a bite of each step down to it.
## At a corner whose two sides are both drier the patch is rounded off, at one whose two sides are
## both wetter its hollow is filled in.
static func edges(
	pos: Vector2i, look: int, neighbour_looks: Dictionary
) -> Dictionary[int, Vector2i]:
	var tiles: Dictionary[int, Vector2i] = {}
	for side_index in SIDES.size():
		var side := SIDES[side_index]
		var other: int = neighbour_looks[side]
		if other < 0 or other == look:
			continue
		var ends: Array = SIDE_ENDS[side]
		var column := (
			(side_index * END_KINDS + _end_kind(look, other, neighbour_looks, ends[0])) * END_KINDS
			+ _end_kind(look, other, neighbour_looks, ends[1])
		)
		_add_pieces(tiles, side_index, look, other, Vector2i(column, edge_phase(pos, side)))
	for corner_index in CORNERS.size():
		var corner := CORNERS[corner_index]
		var first: int = neighbour_looks[CORNER_SIDES[corner] & (NORTH | SOUTH)]
		var second: int = neighbour_looks[CORNER_SIDES[corner] & (EAST | WEST)]
		var other: int
		if first >= 0 and second >= 0 and first < look and second < look:
			other = maxi(first, second)
		elif first > look and second > look:
			other = mini(first, second)
		else:
			continue
		var column := SIDES.size() * END_KINDS * END_KINDS + corner_index
		var variant := PositionHash.of(pos, corner) % PHASES
		_add_pieces(tiles, SIDES.size() + corner_index, look, other, Vector2i(column, variant))
	return tiles


## Where a tile's edge along `side` lies on the wavy line of its line of the grid (see PHASES):
## each tile along it one further, from a start that differs from line to line.
static func edge_phase(pos: Vector2i, side: int) -> int:
	var is_across := side == NORTH or side == SOUTH
	var line := pos.y if is_across else pos.x
	if side == SOUTH or side == EAST:
		line += 1
	var along := pos.x if is_across else pos.y
	return posmod(along + PositionHash.of(Vector2i(line, int(is_across))), PHASES)


## The tile of the edge atlas drawn over a tile on the layer of `slot` (see `edges`) from its side
## or corner `direction`, or NO_TILE.
func edge_at(world_pos: Vector2i, direction: int, slot := 0) -> Vector2i:
	var index := SIDES.find(direction)
	if index < 0:
		index = SIDES.size() + CORNERS.find(direction)
	return _edge_layers[index * PIECE_SLOTS + slot].get_cell_atlas_coords(world_pos)


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


## Draws one tile again, and the edges around it.
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


## How a side's edge between a tile of step `look` and its neighbour of step `other` ends at `end`
## (see SIDE_ENDS and END_RIM).
static func _end_kind(look: int, other: int, neighbour_looks: Dictionary, end: Array) -> int:
	var across: int = neighbour_looks[end[0]]
	var beyond: int = neighbour_looks[end[1]]
	if across < 0:
		return END_RIM
	return END_RUNS_ON if across == look and beyond == other else END_TURNS


## Adds the pieces of an edge from a tile of step `look` to one of step `other` on the layers of
## `direction` (an index into SIDES and then CORNERS), at `place` (the column and the phase) of
## the atlas: the bulge of each wetter step, the wettest on top, or the bite of each drier step,
## the driest on top. The rows of the atlas are those of tools/art/soil_beds.py PIECES.
static func _add_pieces(
	tiles: Dictionary[int, Vector2i], direction: int, look: int, other: int, place: Vector2i
) -> void:
	var is_bulge := other > look
	var step := look
	for slot in absi(other - look):
		step += 1 if is_bulge else -1
		var piece := step + PIECE_SLOTS - 1 if is_bulge else step
		tiles[direction * PIECE_SLOTS + slot] = Vector2i(place.x, piece * PHASES + place.y)


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


## A tile and its neighbours again: the shape of their beds and their edges changed with it.
func _draw_surroundings(world_pos: Vector2i) -> void:
	_draw_tile(world_pos)
	for offset: Vector2i in NEIGHBOUR_OFFSETS.values():
		_draw_tile(world_pos + offset)


func _is_wettable(world_pos: Vector2i) -> bool:
	return _world.is_tilled(world_pos) and not _is_covered.call(world_pos)


## The step a tile shows, or -1 for one that is not tilled or lies under snow.
func _look_at(world_pos: Vector2i) -> int:
	if not _is_wettable(world_pos):
		return -1
	var look := look_for(_world.moisture_at(world_pos))
	return mini(look + 1, LOOKS - 1) if _is_surface_wet else look


func _draw_tile(world_pos: Vector2i) -> void:
	var wet_tile := NO_TILE
	var edge_tiles: Dictionary[int, Vector2i] = {}
	var look := _look_at(world_pos)
	if look >= 0:
		var shape := bed_shape(_world.is_tilled, world_pos)
		if look > 0:
			wet_tile = Vector2i(_columns[shape], look - 1)
		var neighbour_looks := {}
		var is_alike := true
		for neighbour: int in NEIGHBOUR_OFFSETS:
			var neighbour_look := _look_at(world_pos + NEIGHBOUR_OFFSETS[neighbour])
			neighbour_looks[neighbour] = neighbour_look
			is_alike = is_alike and neighbour_look in [look, -1]
		# Most tiles are as wet as all around them: they have no edges.
		if not is_alike:
			edge_tiles = edges(world_pos, look, neighbour_looks)
	_show_cell(self, world_pos, WET_SOURCE, wet_tile)
	if edge_tiles.is_empty() and not _edged_tiles.has(world_pos):
		return
	for index in _edge_layers.size():
		_show_cell(_edge_layers[index], world_pos, EDGE_SOURCE, edge_tiles.get(index, NO_TILE))
	if edge_tiles.is_empty():
		_edged_tiles.erase(world_pos)
	else:
		_edged_tiles[world_pos] = true
