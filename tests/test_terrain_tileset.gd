extends GutTest
## TerrainTileset: the autotile mask and layers, corner fallbacks and decorations.

const MISSING := TerrainTileset.MISSING
const WATER := TerrainTileset.Layer.WATER
const FLOODPLAIN := TerrainTileset.Layer.FLOODPLAIN
const WETLAND := TerrainTileset.Layer.WETLAND
const GRASS := TerrainTileset.Layer.GRASS
const LUSH_GRASS := TerrainTileset.Layer.LUSH_GRASS
const DRY_GRASS := TerrainTileset.Layer.DRY_GRASS
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
	var order: Array[Tile.Terrain] = [
		Tile.Terrain.WATER,
		Tile.Terrain.FLOODPLAIN,
		Tile.Terrain.WETLAND,
		Tile.Terrain.GRASS,
		Tile.Terrain.SOIL,
	]
	for i in range(1, order.size()):
		assert_gt(
			TerrainTileset.terrain_layer(order[i], 0.0),
			TerrainTileset.terrain_layer(order[i - 1], 0.0)
		)


func test_variety_turns_only_grass_lush_or_dry() -> void:
	assert_eq(TerrainTileset.terrain_layer(Tile.Terrain.GRASS, -0.9), LUSH_GRASS)
	assert_eq(TerrainTileset.terrain_layer(Tile.Terrain.GRASS, 0.0), GRASS)
	assert_eq(TerrainTileset.terrain_layer(Tile.Terrain.GRASS, 0.9), DRY_GRASS)
	for variety: float in [-0.9, 0.9]:
		assert_eq(TerrainTileset.terrain_layer(Tile.Terrain.FLOODPLAIN, variety), FLOODPLAIN)
		assert_eq(TerrainTileset.terrain_layer(Tile.Terrain.SOIL, variety), SOIL)


func test_cell_draws_its_corners_layers_and_grass_under_lush_and_dry() -> void:
	var corners := PackedInt32Array([LUSH_GRASS, DRY_GRASS, FLOODPLAIN, FLOODPLAIN])
	assert_eq(
		TerrainTileset.drawn_layers(corners),
		1 << FLOODPLAIN | 1 << GRASS | 1 << LUSH_GRASS | 1 << DRY_GRASS
	)
	# Nothing in between: no wetland under the grass edge.
	corners = PackedInt32Array([GRASS, SOIL, WATER, WATER])
	assert_eq(TerrainTileset.drawn_layers(corners), 1 << WATER | 1 << GRASS | 1 << SOIL)


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
		var cell := _tileset.atlas_cell(GRASS, mask, Vector2i(3, 4))
		assert_eq(cell.y, GRASS)
		assert_lt(cell.x, TerrainTileset.FULL_COLUMN)
		assert_eq(cell.x % TerrainTileset.FULL, mask)


func test_all_layers_of_a_cell_use_the_same_edge_variant() -> void:
	for x in 20:
		var cell := Vector2i(x, -x)
		var variant := _tileset.atlas_cell(GRASS, 3, cell).x / TerrainTileset.FULL
		assert_eq(_tileset.atlas_cell(LUSH_GRASS, 5, cell).x / TerrainTileset.FULL, variant)
		assert_eq(_tileset.atlas_cell(DRY_GRASS, 12, cell).x / TerrainTileset.FULL, variant)


func test_every_atlas_cell_in_use_has_a_tile() -> void:
	var source: TileSetAtlasSource = _tileset.tile_set.get_source(
		TerrainTileset.terrain_source_id(SeasonBlend.Look.SUMMER)
	)
	for layer in TerrainTileset.LAYER_COUNT:
		for y in 8:
			for x in 8:
				var cell := _tileset.atlas_cell(layer, TerrainTileset.FULL, Vector2i(x, y))
				assert_true(source.has_tile(cell), "full tile %s" % cell)
	# Water is always the lowest layer of a cell, so it only ever draws full tiles.
	for layer in range(FLOODPLAIN, TerrainTileset.LAYER_COUNT):
		for mask in range(1, TerrainTileset.FULL):
			for x in 6:
				var cell := _tileset.atlas_cell(layer, mask, Vector2i(x, 0))
				assert_true(source.has_tile(cell), "edge tile %s" % cell)


func test_full_variant_is_stable_and_varies_by_position() -> void:
	var seen := {}
	for y in range(-8, 8):
		for x in range(-8, 8):
			var cell := _tileset.atlas_cell(GRASS, TerrainTileset.FULL, Vector2i(x, y))
			assert_eq(_tileset.atlas_cell(GRASS, TerrainTileset.FULL, Vector2i(x, y)), cell)
			assert_true(cell.x >= TerrainTileset.FULL_COLUMN)
			seen[cell] = true
	assert_gt(seen.size(), 5, "grass uses several full variants")


func test_decorations_gather_where_the_cluster_noise_peaks() -> void:
	var source: TileSetAtlasSource = _tileset.tile_set.get_source(
		TerrainTileset.decoration_source_id(SeasonBlend.Look.SUMMER)
	)
	var sparse := 0
	var clustered := 0
	for y in 20:
		for x in 20:
			var tile := Vector2i(x, y)
			var outside := _tileset.decoration_cell(GRASS, tile, -0.5)
			var inside := _tileset.decoration_cell(GRASS, tile, 0.5)
			assert_eq(_tileset.decoration_cell(GRASS, tile, 0.5), inside, "stable")
			for cell in [outside, inside]:
				if cell != TerrainTileset.NO_DECORATION:
					assert_true(source.has_tile(cell), "decoration %s" % cell)
			sparse += int(outside != TerrainTileset.NO_DECORATION)
			clustered += int(inside != TerrainTileset.NO_DECORATION)
	assert_gt(clustered, sparse * 4)
	assert_gt(sparse, 0)


func test_every_meadow_flower_has_its_tiles_in_every_look() -> void:
	for look: SeasonBlend.Look in SeasonBlend.GROUND_LOOKS:
		var source: TileSetAtlasSource = _tileset.tile_set.get_source(
			TerrainTileset.decoration_source_id(look)
		)
		for species in TerrainTileset.FLOWER_SPECIES:
			for variant in TerrainTileset.FLOWER_VARIANTS:
				var cell := TerrainTileset.flower_cell(species, variant)
				assert_true(source.has_tile(cell), "%s %d in look %d" % [species, variant, look])
	var after_the_last := Vector2i(
		TerrainTileset.FLOWER_SPECIES.size() * TerrainTileset.FLOWER_VARIANTS,
		TerrainTileset.FLOWER_ROW
	)
	var summer: TileSetAtlasSource = _tileset.tile_set.get_source(
		TerrainTileset.decoration_source_id(SeasonBlend.Look.SUMMER)
	)
	assert_false(summer.has_tile(after_the_last), "the art has no more flowers than the list")


func test_tilled_soil_has_no_decorations() -> void:
	for x in 50:
		assert_eq(_tileset.decoration_cell(SOIL, Vector2i(x, 0), 1.0), TerrainTileset.NO_DECORATION)


func test_a_tile_code_holds_its_layer_and_both_looks_apart() -> void:
	for layer in TerrainTileset.LAYER_COUNT:
		for season_look in SeasonBlend.Look.values():
			for weather_look in SeasonBlend.Look.values():
				var code := TerrainTileset.tile_code(layer, season_look, weather_look)
				assert_eq(TerrainTileset.layer_of(code), layer)
				assert_eq(TerrainTileset.season_of(code), season_look)
				assert_eq(TerrainTileset.weather_of(code), weather_look)


func test_the_layer_of_a_missing_corner_is_missing() -> void:
	assert_eq(TerrainTileset.layer_of(MISSING), MISSING)


func test_worn_ground_is_drawn_trodden_or_as_a_path_whatever_its_grass() -> void:
	for terrain in [Tile.Terrain.GRASS, Tile.Terrain.FLOODPLAIN]:
		for variety: float in [-0.9, 0.0, 0.9]:
			assert_eq(
				TerrainTileset.terrain_layer(terrain, variety, PathRules.Stage.TRODDEN),
				TerrainTileset.Layer.TRODDEN
			)
			assert_eq(
				TerrainTileset.terrain_layer(terrain, variety, PathRules.Stage.PATH),
				TerrainTileset.Layer.PATH
			)
