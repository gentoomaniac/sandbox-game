class_name DecorationView
extends Node2D
## The flowers, pebbles and the like scattered on the ground of a World, and the hints of its
## clay spots: two TileMapLayers on the plain tile grid. They are only looks, not world
## objects, and never under an object. WorldView owns it and tells it which tiles to draw.
##
## A decoration comes from a tile's layer and the decoration noise (see TerrainTileset), and
## a plant's decoration is there only in the days of its Vegetation kind. Its picture is the
## look of its tile (the season, snow, frost). The wildlife asks it where flowers bloom.

## Visual-only noise, seeded from the world seed with an offset far from the generator's:
## decoration clusters, a few tiles across.
const DECORATION_SEED_OFFSET := 104729
const DECORATION_FREQUENCY := 0.12


## A place where a decoration could grow: its look, its Vegetation kind and fixed threshold,
## and whether it is drawn now, and in which look.
class DecorationSpot:
	extends RefCounted
	var atlas_cell: Vector2i
	var kind: StringName
	var threshold: float
	var is_shown := false
	## The terrain layer of its tile, which decides how its look shows.
	var layer := 0
	var look := SeasonBlend.Look.SUMMER


## The day the decorations are drawn for. WorldView sets it.
var day := 0
var _world: World
var _tileset: TerrainTileset
var _decoration_noise := FastNoiseLite.new()
var _decorations := TileMapLayer.new()
## The hints of clay spots.
var _clay_hints := TileMapLayer.new()
## Where a decoration could grow, shown or not, so a new day only revisits these tiles.
var _spots: Dictionary[Vector2i, DecorationSpot] = {}


func _init(tileset: TerrainTileset) -> void:
	_tileset = tileset
	_decoration_noise.frequency = DECORATION_FREQUENCY
	_decorations.name = "Decorations"
	_decorations.tile_set = tileset.tile_set
	add_child(_decorations)
	_clay_hints.name = "ClayHints"
	_clay_hints.tile_set = tileset.tile_set
	add_child(_clay_hints)


func show_world(world: World) -> void:
	_world = world
	_decoration_noise.seed = world.world_seed + DECORATION_SEED_OFFSET


## Draws the decoration and the clay hint of a tile of a chunk that was just drawn, unless an
## object covers it. `code` is the tile's (see TerrainTileset.tile_code).
func place(world_pos: Vector2i, code: int, is_covered: bool) -> void:
	var layer := TerrainTileset.layer_of(code)
	_set_clay_hint(world_pos, is_covered)
	var atlas_cell := TerrainTileset.NO_DECORATION
	if not is_covered:
		var cluster := _decoration_noise.get_noise_2dv(Vector2(world_pos))
		atlas_cell = _tileset.decoration_cell(layer, world_pos, cluster)
	_decorations.erase_cell(world_pos)
	if atlas_cell == TerrainTileset.NO_DECORATION:
		_spots.erase(world_pos)
		return
	var spot := DecorationSpot.new()
	spot.atlas_cell = atlas_cell
	spot.kind = TerrainTileset.decoration_kind(atlas_cell)
	spot.layer = layer
	if spot.kind != &"":
		spot.threshold = _world.vegetation.threshold(spot.kind, _world.world_seed, world_pos)
	_spots[world_pos] = spot
	_update(world_pos, spot, code)


## Draws a tile again after something on it changed: whether an object covers it now.
func redraw(world_pos: Vector2i, code: int) -> void:
	place(world_pos, code, _world.object_at(world_pos) != null)


## Brings the decoration of a tile up to date with the day and the look of the tile.
func refresh(world_pos: Vector2i, code: int) -> void:
	var spot: DecorationSpot = _spots.get(world_pos)
	if spot != null:
		_update(world_pos, spot, code)


## Forgets a tile whose chunk unloads.
func forget(world_pos: Vector2i) -> void:
	_decorations.erase_cell(world_pos)
	_clay_hints.erase_cell(world_pos)
	_spots.erase(world_pos)


## Whether a flower is in bloom on a tile today and not under snow (wildlife visits those).
func has_flower(world_pos: Vector2i) -> bool:
	var spot: DecorationSpot = _spots.get(world_pos)
	return (
		spot != null
		and spot.is_shown
		and spot.kind == &"flower"
		and spot.look != SeasonBlend.Look.SNOW
	)


## The tiles within a rectangle (in world pixels) where a flower is in bloom today.
func flower_tiles_within(area: Rect2) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var first := Vector2i((area.position / TerrainTileset.TILE_SIZE).floor())
	var last := Vector2i((area.end / TerrainTileset.TILE_SIZE).floor())
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if has_flower(Vector2i(x, y)):
				tiles.append(Vector2i(x, y))
	return tiles


## Shows the hint of a clay spot that still holds clay, unless an object stands on it.
func _set_clay_hint(world_pos: Vector2i, is_covered: bool) -> void:
	if is_covered or not _world.has_clay(world_pos):
		_clay_hints.erase_cell(world_pos)
	else:
		_clay_hints.set_cell(world_pos, TerrainTileset.CLAY_HINT_SOURCE_ID, Vector2i.ZERO)


## Draws, erases or redraws the decoration of a spot, as its kind is present today and as the
## look of its tile is now.
func _update(world_pos: Vector2i, spot: DecorationSpot, code: int) -> void:
	var should_show := spot.kind == &"" or _world.vegetation.shows(spot.kind, spot.threshold, day)
	var look := TerrainTileset.shown_look(
		spot.layer, TerrainTileset.season_of(code), TerrainTileset.weather_of(code)
	)
	if should_show == spot.is_shown and (look == spot.look or not should_show):
		return
	spot.is_shown = should_show
	spot.look = look
	if should_show:
		_decorations.set_cell(world_pos, TerrainTileset.decoration_source_id(look), spot.atlas_cell)
	else:
		_decorations.erase_cell(world_pos)
