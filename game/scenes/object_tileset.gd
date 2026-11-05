class_name ObjectTileset
extends RefCounted
## The object atlas made by tools/art/generate.py as a TileSet: one row per object type,
## one column per variant (see WorldObjectTypes). Cells are bigger than a tile: an object
## stands on the bottom centre tile of its cell and a tall one (a tree) reaches over the
## tiles north of it. Shorter sprites are drawn on the bottom of their cell.

const ATLAS_PATH := "res://assets/objects.png"
const SOURCE_ID := 0
const CELL_WIDTH := 32
const CELL_HEIGHT := 48

var tile_set := TileSet.new()


func _init() -> void:
	tile_set.tile_size = Vector2i(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = load(ATLAS_PATH)
	source.texture_region_size = Vector2i(CELL_WIDTH, CELL_HEIGHT)
	tile_set.add_source(source, SOURCE_ID)
	# Tiles are drawn centred on their cell; raise them so the cell's bottom edge meets the
	# tile's bottom edge.
	var raise := (CELL_HEIGHT - TerrainTileset.TILE_SIZE) / 2
	for object_type: Dictionary in WorldObjectTypes.TYPES.values():
		for variant: int in object_type["variants"]:
			var atlas_cell := Vector2i(variant, object_type["atlas_row"])
			source.create_tile(atlas_cell)
			source.get_tile_data(atlas_cell, 0).texture_origin = Vector2i(0, raise)


## The atlas cell for an object: its variant comes from its position, so it is stable but
## neighbours differ.
static func atlas_cell(object: WorldObject) -> Vector2i:
	var object_type: Dictionary = WorldObjectTypes.TYPES[object.type]
	var variant := PositionHash.of(object.pos) % int(object_type["variants"])
	return Vector2i(variant, object_type["atlas_row"])
