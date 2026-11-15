extends GutTest
## The natural creeks: a few, winding, joined to the river, with fords, and always the same.

const SEEDS: Array[int] = [1, 42, 7, 1234]
## The columns searched: the bands from the coast to the east, whole rows around the river.
const COLUMNS := Vector2i(-160, 960)
const ROWS := Vector2i(-420, 420)


func _layout(world_seed: int) -> CreekLayout:
	return CreekLayout.new(world_seed, RiverLine.new(world_seed), LandscapeRules.default_rules())


## Every tile that is in a creek: {tile: bed}.
func _creek_tiles(world_seed: int) -> Dictionary[Vector2i, CreekLayout.Bed]:
	var layout := _layout(world_seed)
	var tiles: Dictionary[Vector2i, CreekLayout.Bed] = {}
	for x in range(COLUMNS.x, COLUMNS.y):
		for y in range(ROWS.x, ROWS.y):
			var bed := layout.bed_at(Vector2i(x, y))
			if bed != CreekLayout.Bed.NONE:
				tiles[Vector2i(x, y)] = bed
	return tiles


func test_there_are_a_few_creeks_and_not_many() -> void:
	var spacing := LandscapeRules.default_rules().value("creeks", "spacing")
	for world_seed in SEEDS:
		var bands := {}
		for tile in _creek_tiles(world_seed):
			bands[floori(tile.x / spacing)] = true
		var all_bands := int((COLUMNS.y - COLUMNS.x) / spacing)
		assert_gt(bands.size(), 0, "a creek in seed %d" % world_seed)
		assert_lt(bands.size(), all_bands, "bands without a creek in seed %d" % world_seed)


func test_a_creek_is_one_piece_from_its_source_to_the_river() -> void:
	for world_seed in SEEDS:
		var river := RiverLine.new(world_seed)
		var tiles := _creek_tiles(world_seed)
		var seen := {}
		var creeks := 0
		for start in tiles:
			if seen.has(start):
				continue
			creeks += 1
			var reaches_river := false
			var has_source := false
			var open: Array[Vector2i] = [start]
			seen[start] = true
			while not open.is_empty():
				var tile: Vector2i = open.pop_back()
				reaches_river = reaches_river or absf(tile.y - river.line_y(tile.x)) < 5.0
				has_source = has_source or tiles[tile] == CreekLayout.Bed.SOURCE
				for side in World.CONNECTION_SIDES:
					if tiles.has(tile + side) and not seen.has(tile + side):
						seen[tile + side] = true
						open.append(tile + side)
			assert_true(
				reaches_river,
				"a creek of seed %d at %s ends short of the river" % [world_seed, start]
			)
			assert_true(has_source, "a creek of seed %d at %s has no source" % [world_seed, start])
		assert_gt(creeks, 0, "creeks in seed %d" % world_seed)


func test_a_creek_has_fords_and_a_source() -> void:
	for world_seed in SEEDS:
		var beds := _creek_tiles(world_seed).values()
		assert_true(beds.has(CreekLayout.Bed.FORD), "a ford in seed %d" % world_seed)
		assert_true(beds.has(CreekLayout.Bed.SOURCE), "a source in seed %d" % world_seed)
		assert_gt(
			beds.count(CreekLayout.Bed.WATER), beds.count(CreekLayout.Bed.FORD) * 4, "mostly water"
		)


func test_every_creek_winds_over_at_least_eight_columns() -> void:
	var spacing := int(LandscapeRules.default_rules().value("creeks", "spacing"))
	for world_seed in SEEDS:
		var columns_by_band: Dictionary[int, Array] = {}
		for tile in _creek_tiles(world_seed):
			var columns: Array = columns_by_band.get(floori(tile.x / float(spacing)), [])
			columns.append(tile.x)
			columns_by_band[floori(tile.x / float(spacing))] = columns
		for band in columns_by_band:
			var columns: Array = columns_by_band[band]
			assert_gte(columns.max() - columns.min(), 8, "seed %d band %d" % [world_seed, band])


func test_creeks_are_the_same_for_the_same_seed_and_differ_between_seeds() -> void:
	assert_eq(_creek_tiles(SEEDS[0]), _creek_tiles(SEEDS[0]))
	assert_ne(_creek_tiles(SEEDS[0]).keys(), _creek_tiles(SEEDS[1]).keys())


func test_no_creek_comes_near_the_coast_and_the_sea_dyke_is_unbroken() -> void:
	var rules := LandscapeRules.default_rules()
	var coast_edge := rules.value("coast", "line_x") + rules.value("coast", "wander")
	for world_seed in [7, 42]:
		var generator := WorldGenerator.new(world_seed)
		for tile in _creek_tiles(world_seed):
			assert_gt(
				float(tile.x), coast_edge + 3.0, "a creek at %s in seed %d" % [tile, world_seed]
			)
		for y in range(ROWS.x, ROWS.y, 3):
			var x := int(coast_edge) - 60
			while (
				generator.terrain_at(Vector2i(x, y)) != Tile.Terrain.GRASS and x < coast_edge + 60
			):
				x += 1
			var first_land := Vector2i(x, y)
			if generator.terrain_at(first_land + Vector2i.LEFT) == Tile.Terrain.SALT_MARSH:
				var has_dyke := false
				for land in [first_land, first_land + Vector2i.RIGHT]:
					var type := generator.object_type_at(land, generator.terrain_at(land))
					has_dyke = has_dyke or type == WorldObjectTypes.DYKE
				assert_true(has_dyke, "no dyke at %s in seed %d" % [first_land, world_seed])


func test_the_generator_makes_water_of_a_creek_and_walkable_ground_of_a_ford() -> void:
	var generator := WorldGenerator.new(SEEDS[0])
	var layout := _layout(SEEDS[0])
	var tiles := _creek_tiles(SEEDS[0])
	var checked := 0
	for tile in tiles:
		# Out on the foreshore there is no creek, and in the river it is the river's own water.
		if tile.x < -240 or generator._river_distance(tile) < WorldGenerator.RIVER_HALF_WIDTH:
			continue
		checked += 1
		match layout.bed_at(tile):
			CreekLayout.Bed.WATER:
				assert_eq(generator.terrain_at(tile), Tile.Terrain.WATER, str(tile))
			CreekLayout.Bed.FORD:
				var ford := Tile.new()
				ford.terrain = generator.terrain_at(tile)
				assert_true(ford.is_walkable(), "%s is no ford" % tile)
			CreekLayout.Bed.SOURCE:
				assert_eq(generator.terrain_at(tile), Tile.Terrain.WETLAND, str(tile))
	assert_gt(checked, 100, "creek tiles checked")
