class_name ObjectTileset
extends RefCounted
## The object atlas made by tools/art/generate.py as a TileSet: one row per object type,
## one column per variant (see WorldObjectTypes). Cells are bigger than a tile: an object
## stands on the bottom centre tile of its cell and a tall one (a tree) reaches over the
## tiles around it. An object on several tiles is centred on its footprint, with the
## cell's bottom on the footprint's bottom, so it is drawn from its own (top left) tile
## shifted accordingly.

const ATLAS_PATH := "res://assets/objects.png"
const SOURCE_ID := 0
const CELL_WIDTH := 48
const CELL_HEIGHT := 80

var tile_set := TileSet.new()
var _source := TileSetAtlasSource.new()


func _init() -> void:
	tile_set.tile_size = Vector2i(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE)
	_source.texture = load(ATLAS_PATH)
	_source.texture_region_size = Vector2i(CELL_WIDTH, CELL_HEIGHT)
	tile_set.add_source(_source, SOURCE_ID)
	for object_type: Dictionary in WorldObjectTypes.TYPES.values():
		if not object_type.has("atlas_row"):
			continue
		for variant in looks_count(object_type):
			var atlas_cell := Vector2i(variant, object_type["atlas_row"])
			_source.create_tile(atlas_cell)
			var tile_data := _source.get_tile_data(atlas_cell, 0)
			tile_data.texture_origin = cell_origin(object_type["footprint"])
			# Sorted by the middle of the footprint's bottom row, like the player standing there.
			tile_data.y_sort_origin = (object_type["footprint"].y - 1) * TerrainTileset.TILE_SIZE


## Shows the season's pictures; the layout is the same in every season.
func set_season(season: GameClock.Season) -> void:
	_source.texture = load(SeasonalArt.path(ATLAS_PATH, season))


## How many pictures a type has in its atlas row: its variants, and for a bush that can be
## picked the same again, picked.
static func looks_count(object_type: Dictionary) -> int:
	var picked_looks: int = object_type["variants"] if object_type.has("regrow_days") else 0
	return object_type["variants"] + picked_looks


## Where a cell is drawn relative to its tile: texture_origin moves it up and left. Tiles are
## drawn centred on their cell; raise it so the cell's bottom edge meets the bottom edge of
## the footprint, and shift it over so the cell is centred on the footprint.
static func cell_origin(footprint: Vector2i) -> Vector2i:
	var tile_size := TerrainTileset.TILE_SIZE
	return Vector2i(
		-(footprint.x - 1) * tile_size / 2,
		(CELL_HEIGHT - tile_size) / 2 - (footprint.y - 1) * tile_size
	)


## The atlas cell for an object: a crop's variant is its growth stage; for the others it
## comes from the position, so it is stable but neighbours differ. A picked bush has its
## variant's picked look.
static func atlas_cell(object: WorldObject) -> Vector2i:
	var object_type: Dictionary = WorldObjectTypes.TYPES[object.type]
	var variant: int = (
		object.growth_stage()
		if object.is_crop()
		else PositionHash.of(object.pos) % int(object_type["variants"])
	)
	if object.is_picked():
		variant += object_type["variants"]
	return Vector2i(variant, object_type["atlas_row"])
