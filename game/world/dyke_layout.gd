class_name DykeLayout
extends RefCounted
## The dykes of data/landscape.cfg ([dykes]): the sea dyke on the first land along the coast, and
## the river dykes along the floodplain's edge, in the stretches the dyke noise picks. A pure
## function of the seed and the tile position. The dykes are the only work of men in the open land.

## How far a dyke's tile can lie past the edge of the land it runs along (the coast line, the
## floodplain's edge): the edge steps at most 2 tiles from one row to the next (from one column
## to the next for the river), and the dyke takes the tiles along a step and cuts off a narrow
## bulge (see `_is_on_edge_line`), which together is less than this.
const LINE_REACH := 8.0
## A tile further than this from the river's centre line can't carry a river dyke.
const PROBE_DISTANCE := (
	WorldGenerator.RIVER_HALF_WIDTH + WorldGenerator.FLOODPLAIN_WIDTH + LINE_REACH
)
## The places along an edge that decide whether a tile is on its dyke (see `_is_on_edge_line`):
## this many either side of its own.
const EDGE_LINE_SPAN := 3

## The dyke noise picks the stretches of the floodplain's edge that have a dyke. Two octaves only:
## more add small wobbles, which near the threshold cut a stretch into pieces a few tiles long.
const FREQUENCY := 0.01
const OCTAVES := 2
const SEED_OFFSET := 11

var _river: RiverLine
var _coast: CoastLayout
var _noise := FastNoiseLite.new()
## The number of data/landscape.cfg (see there).
var _stretch_above: float


func _init(
	world_seed: int, river: RiverLine, coast: CoastLayout, landscape: LandscapeRules
) -> void:
	_river = river
	_coast = coast
	_noise.seed = world_seed + SEED_OFFSET
	_noise.frequency = FREQUENCY
	_noise.fractal_octaves = OCTAVES
	_stretch_above = landscape.value("dykes", "stretch_above")


## Whether a tile of this natural terrain has a dyke: by the sea or along the river.
func is_dyke(
	world_pos: Vector2i, natural: Tile.Terrain, river_distance: float, generator: WorldGenerator
) -> bool:
	return (
		_is_sea_dyke(world_pos, natural)
		or _is_river_dyke(world_pos, natural, river_distance, generator)
	)


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
	if not _coast.is_within(world_pos, LINE_REACH):
		return false
	return _is_on_edge_line(world_pos.y, world_pos.x, _coast.first_land_x)


## Whether a tile of this natural terrain has a river dyke: land on the line along the edge of the
## floodplain (see `_is_on_edge_line`), north or south of the river, in a column of a stretch the
## dyke noise picks there. A whole column is in or out, so a stretch begins and ends cleanly, on
## a tile joined on one side. Where a creek cuts the line, a tile left on its own between its
## water has none.
func _is_river_dyke(
	world_pos: Vector2i, natural: Tile.Terrain, river_distance: float, generator: WorldGenerator
) -> bool:
	if not _is_on_river_dyke_line(world_pos, natural, river_distance):
		return false
	for side in World.CONNECTION_SIDES:
		var neighbour := world_pos + side
		var neighbour_terrain := generator.terrain_at(neighbour)
		var neighbour_distance := _river.distance(neighbour)
		if _is_on_river_dyke_line(neighbour, neighbour_terrain, neighbour_distance):
			return true
	return false


## `_is_river_dyke`, but for the tiles left on their own.
func _is_on_river_dyke_line(
	world_pos: Vector2i, natural: Tile.Terrain, river_distance: float
) -> bool:
	if natural != Tile.Terrain.GRASS and natural != Tile.Terrain.WETLAND:
		return false
	if river_distance >= PROBE_DISTANCE:
		return false
	var is_north := world_pos.y < _river.line_y(world_pos.x)
	# Across the edge into the land: north of the river up, south of it down.
	var edge := _north_land_edge if is_north else _south_land_edge
	var across := -world_pos.y if is_north else world_pos.y
	if not _is_on_edge_line(world_pos.x, across, edge):
		return false
	var edge_place: int = edge.call(world_pos.x)
	var edge_row := -edge_place if is_north else edge_place
	return _noise.get_noise_2d(world_pos.x, edge_row) > _stretch_above


## The first row of the land north of the floodplain in a column, counted upwards (negated), so
## it grows into the land as `_is_on_edge_line` needs.
func _north_land_edge(x: int) -> int:
	var flood_edge := (
		_river.line_y(x)
		- _river.widening_at(x)
		- WorldGenerator.RIVER_HALF_WIDTH
		- WorldGenerator.FLOODPLAIN_WIDTH
	)
	return -floori(flood_edge)


## The first row of the land south of the floodplain in a column.
func _south_land_edge(x: int) -> int:
	var flood_edge := (
		_river.line_y(x)
		+ _river.widening_at(x)
		+ WorldGenerator.RIVER_HALF_WIDTH
		+ WorldGenerator.FLOODPLAIN_WIDTH
	)
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
