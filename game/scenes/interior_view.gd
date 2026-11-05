class_name InteriorView
extends Node2D
## Renders an Interior from its state: floor and walls on one tile layer, its objects on
## another, in the y-sorted `entities` node where the player stands among them. Tiles come
## from assets/interior.png, the same image the Tiled tileset (maps/interiors/interior.tsx)
## uses, with the cells in this order: floor, wall, doormat, bed, table.

const ATLAS_PATH := "res://assets/interior.png"
const SOURCE_ID := 0
const FLOOR_CELL := Vector2i(0, 0)
const WALL_CELL := Vector2i(1, 0)
const DOORMAT_CELL := Vector2i(2, 0)
## Beyond the room, so it does not show the (hidden) world's emptiness.
const BACKDROP := Color("1d1b26")
const BACKDROP_RADIUS := 1000.0

## Y-sorted: the player is added here.
var entities := Node2D.new()
var _ground := TileMapLayer.new()
var _objects := TileMapLayer.new()


func _ready() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = load(ATLAS_PATH)
	source.texture_region_size = tile_set.tile_size
	tile_set.add_source(source, SOURCE_ID)
	for column in source.texture.get_width() / TerrainTileset.TILE_SIZE:
		source.create_tile(Vector2i(column, 0))
	_ground.name = "Ground"
	_ground.tile_set = tile_set
	add_child(_ground)
	_objects.name = "Objects"
	_objects.tile_set = tile_set
	_objects.y_sort_enabled = true
	entities.name = "Entities"
	entities.y_sort_enabled = true
	entities.add_child(_objects)
	add_child(entities)


func show_interior(interior: Interior) -> void:
	_ground.clear()
	_objects.clear()
	for y in interior.size.y:
		for x in interior.size.x:
			var pos := Vector2i(x, y)
			var tile := interior.tile_at(pos)
			if tile != null:
				_ground.set_cell(pos, SOURCE_ID, _ground_cell(tile, pos == interior.exit_tile))
	for object in interior.objects():
		var cell: Vector2i = WorldObjectTypes.TYPES[object.type]["interior_cell"]
		_objects.set_cell(object.pos, SOURCE_ID, cell)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ONE * -BACKDROP_RADIUS, Vector2.ONE * 2 * BACKDROP_RADIUS), BACKDROP)


func _ground_cell(tile: Tile, is_exit: bool) -> Vector2i:
	if is_exit:
		return DOORMAT_CELL
	return WALL_CELL if tile.terrain == Tile.Terrain.WALL else FLOOR_CELL
