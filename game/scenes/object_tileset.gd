class_name ObjectTileset
extends RefCounted
## The object atlas made by tools/art/generate.py as a TileSet: one row per object type,
## one column per variant (see WorldObjectTypes). Cells are bigger than a tile: an object
## stands on the bottom centre tile of its cell and a tall one (a tree) reaches over the
## tiles around it. An object on several tiles is centred on its footprint, with the
## cell's bottom on the footprint's bottom, so it is drawn from its own (top left) tile
## shifted accordingly.
##
## Every crop has a sheet of its own, a source of its own in the same TileSet, built from the
## crop's `sheet` in data/crops.cfg: a growth stage per cell and then the dead one, side by
## side. Its cells are as tall as the sheet and as wide as the sheet is wide over the number of
## cells, and stand with their bottom on the bottom of the crop's tile.

const ATLAS_PATH := "res://assets/objects.png"
const CELL_WIDTH := 48
const CELL_HEIGHT := 80

var tile_set := TileSet.new()
## The source of each crop's sheet, by crop type.
var _crop_sources: Dictionary[StringName, int] = {}


## One atlas source per look (see SeasonBlend.Look), with the same tiles: a source's id is its
## look. Then one source per crop, with the ids that follow. The tiles of plants and fires get
## the materials of `motion` (none without it).
func _init(crop_rules := CropRules.default_rules(), motion: AmbientMotion = null) -> void:
	tile_set.tile_size = Vector2i(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE)
	for look: SeasonBlend.Look in SeasonBlend.Look.values():
		var source := TileSetAtlasSource.new()
		source.texture = load(SeasonalArt.path(ATLAS_PATH, look))
		source.texture_region_size = Vector2i(CELL_WIDTH, CELL_HEIGHT)
		# The motion shaders find a pixel's place in its cell from its texture coordinates.
		source.use_texture_padding = false
		tile_set.add_source(source, look)
		for type: StringName in WorldObjectTypes.TYPES:
			var object_type: Dictionary = WorldObjectTypes.TYPES[type]
			if not object_type.has("atlas_row"):
				continue
			for variant in looks_count(object_type):
				var atlas_cell := Vector2i(variant, object_type["atlas_row"])
				source.create_tile(atlas_cell)
				var tile_data := source.get_tile_data(atlas_cell, 0)
				tile_data.texture_origin = cell_origin(object_type["footprint"])
				# Sorted by the middle of the footprint's bottom row, like the player standing there.
				tile_data.y_sort_origin = (
					(object_type["footprint"].y - 1) * TerrainTileset.TILE_SIZE
				)
				if motion != null:
					tile_data.material = motion.object_material(type)
	for crop_id in crop_rules.crop_ids():
		_add_crop_sheet(crop_id, crop_rules.crop(crop_id)["sheet"], motion)


## The source that has the sheet of a crop type. Everything else is drawn from the source of its
## look (see SeasonBlend.Look).
func crop_source_id(crop_type: StringName) -> int:
	return _crop_sources[crop_type]


## A crop's sheet is the same in every season.
func _add_crop_sheet(crop_id: StringName, sheet_path: String, motion: AmbientMotion) -> void:
	var source := TileSetAtlasSource.new()
	var sheet: Texture2D = load(sheet_path)
	source.texture = sheet
	var cell_size := Vector2i(sheet.get_width() / (CropRules.STAGES + 1), sheet.get_height())
	source.texture_region_size = cell_size
	source.use_texture_padding = false
	_crop_sources[crop_id] = tile_set.add_source(source)
	for look in CropRules.STAGES + 1:
		source.create_tile(Vector2i(look, 0))
		var tile_data := source.get_tile_data(Vector2i(look, 0), 0)
		tile_data.texture_origin = Vector2i(0, (cell_size.y - TerrainTileset.TILE_SIZE) / 2)
		if motion != null:
			tile_data.material = motion.crop_material(cell_size)


## How many pictures a type has in its atlas row: its variants, and for a bush that can be
## picked the same again, picked.
static func looks_count(object_type: Dictionary) -> int:
	var can_be_picked: bool = object_type.has("regrow_days") or object_type.has("regrow_growth")
	var picked_looks: int = object_type["variants"] if can_be_picked else 0
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


## The cell for an object in its source: a crop's is its growth stage, or the dead one; for the
## others the variant comes from the position, so it is stable but neighbours differ. A picked
## bush has its variant's picked look, and so does a bush that is `is_bare` (out of its fruit
## season).
static func atlas_cell(object: WorldObject, is_bare := false) -> Vector2i:
	if object.is_crop():
		return Vector2i(CropLife.look(object), 0)
	var object_type: Dictionary = WorldObjectTypes.TYPES[object.type]
	var variant: int = PositionHash.of(object.pos) % int(object_type["variants"])
	if object.is_picked() or is_bare:
		variant += object_type["variants"]
	return Vector2i(variant, object_type["atlas_row"])
