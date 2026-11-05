class_name SoilWetness
extends TileMapLayer
## Darkens tilled soil that is damp or wet (see World `moisture_at`): speckles of dark soil on
## the plain tile grid, under the objects. It follows the world's moisture and tilling signals,
## so it needs nothing from chunk streaming: tilled tiles are drawn wherever they are.

const TEXTURE_PATH := "res://assets/soil_wet.png"
const TILE_SIZE := TerrainTileset.TILE_SIZE
## The moisture from which soil looks damp, and wet.
const DAMP_FROM := 0.35
const WET_FROM := 0.7

var _world: World


func _init() -> void:
	name = "SoilWetness"
	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = load(TEXTURE_PATH)
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, 0)
	source.create_tile(Vector2i(0, 0))
	source.create_tile(Vector2i(1, 0))


## Draws the world's tilled soil and follows it from now on.
func show_world(world: World) -> void:
	_world = world
	_world.soil_moisture_changed.connect(_draw_tile)
	_world.tile_changed.connect(_draw_tile)
	for pos in _world.tilled_tiles():
		_draw_tile(pos)


## The picture of the atlas for a moisture, or -1 for none: dry soil looks as it is.
static func look_for(moisture: float) -> int:
	if moisture >= WET_FROM:
		return 1
	return 0 if moisture >= DAMP_FROM else -1


func _draw_tile(world_pos: Vector2i) -> void:
	var look := look_for(_world.moisture_at(world_pos)) if _world.is_tilled(world_pos) else -1
	if look < 0:
		erase_cell(world_pos)
	else:
		set_cell(world_pos, 0, Vector2i(look, 0))
