extends GutTest

const MISSING := TerrainTileset.MISSING
const WATER := TerrainTileset.Layer.WATER
const FLOODPLAIN := TerrainTileset.Layer.FLOODPLAIN
const WETLAND := TerrainTileset.Layer.WETLAND
const GRASS := TerrainTileset.Layer.GRASS
const SOIL := TerrainTileset.Layer.SOIL

var _tileset: TerrainTileset


func before_all() -> void:
	_tileset = TerrainTileset.new()


func test_mask_counts_corners_on_the_layer_or_above() -> void:
	var corners := PackedInt32Array([GRASS, SOIL, WATER, WETLAND])
	assert_eq(TerrainTileset.mask_for(corners, WATER), TerrainTileset.FULL)
	assert_eq(
		TerrainTileset.mask_for(corners, WETLAND),
		TerrainTileset.TOP_LEFT | TerrainTileset.TOP_RIGHT | TerrainTileset.BOTTOM_RIGHT
	)
	assert_eq(
		TerrainTileset.mask_for(corners, GRASS), TerrainTileset.TOP_LEFT | TerrainTileset.TOP_RIGHT
	)
	assert_eq(TerrainTileset.mask_for(corners, SOIL), TerrainTileset.TOP_RIGHT)


func test_layer_order_follows_terrain_priority() -> void:
	var order: Array = [
		Tile.Terrain.WATER,
		Tile.Terrain.FLOODPLAIN,
		Tile.Terrain.WETLAND,
		Tile.Terrain.GRASS,
		Tile.Terrain.SOIL,
	]
	for priority in order.size():
		assert_eq(TerrainTileset.LAYER_OF_TERRAIN[order[priority]], priority)


func test_missing_corner_takes_the_one_beside_it() -> void:
	var corners := PackedInt32Array([MISSING, GRASS, MISSING, WATER])
	TerrainTileset.fill_missing_corners(corners)
	assert_eq(corners, PackedInt32Array([GRASS, GRASS, WATER, WATER]))


func test_missing_corners_fall_back_to_above_below_then_diagonal() -> void:
	var corners := PackedInt32Array([MISSING, MISSING, SOIL, WATER])
	TerrainTileset.fill_missing_corners(corners)
	assert_eq(corners, PackedInt32Array([SOIL, WATER, SOIL, WATER]))

	corners = PackedInt32Array([MISSING, MISSING, MISSING, WETLAND])
	TerrainTileset.fill_missing_corners(corners)
	assert_eq(corners, PackedInt32Array([WETLAND, WETLAND, WETLAND, WETLAND]))


func test_edge_shapes_sit_in_their_mask_column() -> void:
	for mask in range(1, TerrainTileset.FULL):
		assert_eq(_tileset.atlas_cell(GRASS, mask, Vector2i(3, 4)), Vector2i(mask, GRASS))


func test_every_atlas_cell_in_use_has_a_tile() -> void:
	var source: TileSetAtlasSource = _tileset.tile_set.get_source(TerrainTileset.SOURCE_ID)
	for layer in TerrainTileset.LAYER_COUNT:
		for y in 8:
			for x in 8:
				var cell := _tileset.atlas_cell(layer, TerrainTileset.FULL, Vector2i(x, y))
				assert_true(source.has_tile(cell), "full tile %s" % cell)
	# Water is always the lowest layer of a cell, so it only ever draws full tiles.
	for layer in range(FLOODPLAIN, TerrainTileset.LAYER_COUNT):
		for mask in range(1, TerrainTileset.FULL):
			var cell := _tileset.atlas_cell(layer, mask, Vector2i.ZERO)
			assert_true(source.has_tile(cell), "edge tile %s" % cell)


func test_full_variant_is_stable_and_varies_by_position() -> void:
	var seen := {}
	for y in range(-8, 8):
		for x in range(-8, 8):
			var cell := _tileset.atlas_cell(GRASS, TerrainTileset.FULL, Vector2i(x, y))
			assert_eq(_tileset.atlas_cell(GRASS, TerrainTileset.FULL, Vector2i(x, y)), cell)
			assert_true(cell.x >= TerrainTileset.FULL)
			seen[cell] = true
	assert_gt(seen.size(), 3, "grass uses several full variants")
