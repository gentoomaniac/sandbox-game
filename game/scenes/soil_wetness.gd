class_name SoilWetness
extends TileMapLayer
## Darkens tilled soil that is damp or wet (see World `moisture_at`): dashes of dark soil on the
## plain tile grid, over the soil terrain and under every look overlay and the objects. It
## follows the world's moisture and tilling signals, so it needs nothing from chunk streaming:
## tilled tiles are drawn wherever they are. Soil that snow lies on (see `show_world`) is not
## drawn wet.

const TEXTURE_PATH := "res://assets/soil_wet.png"
const TILE_SIZE := TerrainTileset.TILE_SIZE
## The moisture from which soil looks damp, and wet.
const DAMP_FROM := 0.35
const WET_FROM := 0.7

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
	source.create_tile(Vector2i(0, 0))
	source.create_tile(Vector2i(1, 0))


## Draws the world's tilled soil and follows it from now on. `is_covered` tells for a world tile
## whether snow covers it, and then it is left out; call `redraw_tile` when that changes.
func show_world(world: World, is_covered := func(_pos: Vector2i) -> bool: return false) -> void:
	_world = world
	_is_covered = is_covered
	_world.soil_moisture_changed.connect(_draw_tile)
	_world.tile_changed.connect(_draw_tile)
	for pos in _world.tilled_tiles():
		_draw_tile(pos)


## Shows the wet soil of the chosen art set (see ArtSet).
func show_art_set() -> void:
	var source: TileSetAtlasSource = tile_set.get_source(0)
	source.texture = load(ArtSet.path(TEXTURE_PATH))


## The picture of the atlas for a moisture, or -1 for none: dry soil looks as it is.
static func look_for(moisture: float) -> int:
	if moisture >= WET_FROM:
		return 1
	return 0 if moisture >= DAMP_FROM else -1


## How many tiles are drawn damp or wet. The marks stay wherever the soil is, loaded chunks or
## not, so this is part of what the world view keeps resident.
func mark_count() -> int:
	return get_used_cells().size()


## Draws one tile again.
func redraw_tile(world_pos: Vector2i) -> void:
	_draw_tile(world_pos)


func _draw_tile(world_pos: Vector2i) -> void:
	var is_wettable: bool = _world.is_tilled(world_pos) and not _is_covered.call(world_pos)
	var look := look_for(_world.moisture_at(world_pos)) if is_wettable else -1
	if look < 0:
		erase_cell(world_pos)
	else:
		set_cell(world_pos, 0, Vector2i(look, 0))
