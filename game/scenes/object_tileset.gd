class_name ObjectTileset
extends RefCounted
## The object atlas assembled by tools/art/generate.py as a TileSet: one row per object type,
## one column per variant (see WorldObjectTypes). Cells are bigger than a tile: an object
## stands on the bottom centre tile of its cell and a tall one (a tree) reaches over the
## tiles around it. An object on several tiles is centred on its footprint, with the
## cell's bottom on the footprint's bottom, so it is drawn from its own (top left) tile
## shifted accordingly.
##
## Every crop has a sheet of its own, a source of its own in the same TileSet, built from the
## crop's `sheet` in data/crops.cfg: a growth stage per cell and then the dead one, side by
## side. Its cells are as tall as the sheet and as wide as the sheet is wide over the number of
## cells, and stand with their bottom on the bottom of the crop's tile. The sheets are those of
## the chosen art set (see ArtSet), which WorldView shows anew by `show_art_set`.

const ATLAS_PATH := "res://assets/objects.png"
## The looks an object is drawn in: the foliage of the seasons and the steps of the leaf-out. The
## frost and the snow are laid over them by the shader (see object_cover.gdshaderinc).
const LOOKS: Array[SeasonBlend.Look] = [
	SeasonBlend.Look.SPRING,
	SeasonBlend.Look.SUMMER,
	SeasonBlend.Look.AUTUMN,
	SeasonBlend.Look.BARE,
	SeasonBlend.Look.BUDS,
	SeasonBlend.Look.YOUNG_LEAVES,
]
## A cell is three tiles wide and five tall (as OBJECT_CELL_WIDTH and OBJECT_CELL_HEIGHT in
## tools/art/canvas.py).
const CELL_WIDTH := 3 * TerrainTileset.TILE_SIZE
const CELL_HEIGHT := 5 * TerrainTileset.TILE_SIZE

var tile_set := TileSet.new()
## The source of each crop's sheet, by crop type.
var _crop_sources: Dictionary[StringName, int] = {}
## Whether the atlases shown are the classic art's (see ArtSet).
var _is_classic := ArtSet.is_classic
## The sheet of each crop type in the new art (see ArtSet).
var _crop_sheets: Dictionary[StringName, String] = {}
## Whose materials the plants, the fires and the crops get (none without it).
var _motion: AmbientMotion


## One atlas source per look (see LOOKS), with the same tiles: a source's id is its look; the
## classic art's atlases have the same cells (see `show_art_set`). Then one source per crop, with
## the ids that follow. The tiles of plants and fires get the materials of `motion` (none
## without it).
func _init(crop_rules := CropRules.default_rules(), motion: AmbientMotion = null) -> void:
	_motion = motion
	tile_set.tile_size = Vector2i(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE)
	for look in LOOKS:
		var source := TileSetAtlasSource.new()
		source.texture = load(picture(look))
		source.texture_region_size = Vector2i(CELL_WIDTH, CELL_HEIGHT)
		# The motion shaders find a pixel's place in its cell from its texture coordinates.
		source.use_texture_padding = false
		tile_set.add_source(source, look)
		for type: StringName in WorldObjectTypes.TYPES:
			var object_type: Dictionary = WorldObjectTypes.TYPES[type]
			if not object_type.has("atlas_row"):
				continue
			var cells_wide: int = object_type.get("cells_wide", 1)
			for variant in looks_count(object_type):
				var atlas_cell := Vector2i(variant * cells_wide, object_type["atlas_row"])
				source.create_tile(atlas_cell, Vector2i(cells_wide, 1))
				var tile_data := source.get_tile_data(atlas_cell, 0)
				tile_data.texture_origin = cell_origin(object_type["footprint"])
				# Sorted by the middle of the footprint's bottom row, like the player standing there;
				# a deck as if it lay a tile further up, so that whoever stands on it is drawn over it.
				var rows_down: int = object_type["footprint"].y - 1
				if object_type.get("deck", false):
					rows_down -= 1
				tile_data.y_sort_origin = rows_down * TerrainTileset.TILE_SIZE
				if motion != null:
					tile_data.material = motion.object_material(type)
	for crop_id in crop_rules.crop_ids():
		_add_crop_sheet(crop_id, crop_rules.crop(crop_id)["sheet"])


## Shows the atlases and the crops' sheets of the chosen art set (see ArtSet), if they are not
## shown yet. Both sets have the same cells, so the tiles stay and only their pictures change.
func show_art_set() -> void:
	if _is_classic == ArtSet.is_classic:
		return
	_is_classic = ArtSet.is_classic
	for look in LOOKS:
		var source: TileSetAtlasSource = tile_set.get_source(look)
		source.texture = load(picture(look))
	for crop_id in _crop_sources:
		_show_crop_sheet(crop_id)


## The object atlas in a look, in the chosen art set.
static func picture(look: SeasonBlend.Look) -> String:
	return ArtSet.path(SeasonalArt.path(ATLAS_PATH, look))


## The source that has the sheet of a crop type. Everything else is drawn from the source of its
## look (see SeasonBlend.Look).
func crop_source_id(crop_type: StringName) -> int:
	return _crop_sources[crop_type]


## A crop's sheet is the same in every season.
func _add_crop_sheet(crop_id: StringName, sheet_path: String) -> void:
	var source := TileSetAtlasSource.new()
	var sheet: Texture2D = load(sheet_path)
	source.texture = sheet
	var cell_size := Vector2i(sheet.get_width() / (CropRules.STAGES + 1), sheet.get_height())
	source.texture_region_size = cell_size
	source.use_texture_padding = false
	for look in CropRules.STAGES + 1:
		source.create_tile(Vector2i(look, 0))
		var tile_data := source.get_tile_data(Vector2i(look, 0), 0)
		tile_data.texture_origin = Vector2i(0, (cell_size.y - TerrainTileset.TILE_SIZE) / 2)
	_crop_sources[crop_id] = tile_set.add_source(source)
	_crop_sheets[crop_id] = sheet_path
	_show_crop_sheet(crop_id)


## Gives the crop's tiles its sheet in the chosen art set, and the sway of that art: a classic
## sheet is 16 px art doubled. A crop drawn after the crops went native has no classic sheet and
## shows its new one in both sets.
func _show_crop_sheet(crop_id: StringName) -> void:
	var source: TileSetAtlasSource = tile_set.get_source(_crop_sources[crop_id])
	var path := ArtSet.path(_crop_sheets[crop_id])
	source.texture = load(path)
	if _motion == null:
		return
	var is_classic := path != _crop_sheets[crop_id]
	var material := _motion.crop_material(
		source.texture_region_size, TerrainTileset.ART_16_SCALE if is_classic else 1
	)
	for look in CropRules.STAGES + 1:
		source.get_tile_data(Vector2i(look, 0), 0).material = material


## How many pictures a type has in its atlas row: its variants, and for a bush that can be
## picked the same again, picked; a line object has a picture per connection mask of each. A
## picture spans `cells_wide` cells.
static func looks_count(object_type: Dictionary) -> int:
	if object_type.has("connects"):
		return object_type["variants"] * WorldObjectTypes.CONNECTION_LOOKS
	if object_type.has("stock_capacity"):
		return WorldObjectTypes.STOCK_LOOKS
	if object_type.has("sway_frames"):
		return object_type["sway_frames"]
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
## others the variant comes from the position, so it is stable but neighbours differ. A line
## object (one that `connects`) has the picture of its variant for its connection mask,
## `connections` (see World `connections`). A trough or a hay rack has the picture of how full it is
## (see ObjectStock `look`). A scarecrow has the picture of `sway_frame`, how the wind blows it
## (see AmbientMotion `scarecrow_frame`). A picked bush has its variant's picked look, and so
## does a bush that is `is_bare` (out of its fruit season).
static func atlas_cell(
	object: WorldObject, is_bare := false, connections := 0, sway_frame := 0
) -> Vector2i:
	if object.is_crop():
		return Vector2i(CropLife.look(object), 0)
	var object_type: Dictionary = WorldObjectTypes.TYPES[object.type]
	if object_type.has("stock_capacity"):
		return Vector2i(ObjectStock.look(object), object_type["atlas_row"])
	if object_type.has("sway_frames"):
		return Vector2i(sway_frame, object_type["atlas_row"])
	var variant: int = PositionHash.of(object.pos) % int(object_type["variants"])
	if object_type.has("connects"):
		var column := variant * WorldObjectTypes.CONNECTION_LOOKS + connections
		return Vector2i(column, object_type["atlas_row"])
	if object.is_picked() or is_bare:
		variant += object_type["variants"]
	return Vector2i(variant * object_type.get("cells_wide", 1), object_type["atlas_row"])
