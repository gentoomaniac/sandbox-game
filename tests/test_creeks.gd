extends GutTest
## The natural creeks: a few, winding, joined to the river, with fords, and always the same.

const SEEDS: Array[int] = [1, 42, 7, 1234]

const EIGHT_STEPS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1),
]
## The seeds of SEEDS and three more with bends of up to 3.8 tiles a row (seed 10 is the steepest of
## the first 80).
const SEEDS_WITH_A_STEEP_BEND: Array[int] = [1, 42, 7, 1234, 10, 4, 13]
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


## The ford tiles that touch each other: [[tile, ...], ...].
func _ford_patches(tiles: Dictionary[Vector2i, CreekLayout.Bed]) -> Array[Array]:
	var patches: Array[Array] = []
	var seen := {}
	for start in tiles:
		if tiles[start] != CreekLayout.Bed.FORD or seen.has(start):
			continue
		var patch: Array[Vector2i] = []
		var open: Array[Vector2i] = [start]
		seen[start] = true
		while not open.is_empty():
			var tile: Vector2i = open.pop_back()
			patch.append(tile)
			for side in World.CONNECTION_SIDES:
				if tiles.get(tile + side) == CreekLayout.Bed.FORD and not seen.has(tile + side):
					seen[tile + side] = true
					open.append(tile + side)
		patches.append(patch)
	return patches


func test_a_ford_is_about_three_tiles_long_whichever_way_the_creek_runs() -> void:
	for world_seed in SEEDS:
		var patches := _ford_patches(_creek_tiles(world_seed))
		assert_gt(patches.size(), 3, "fords in seed %d" % world_seed)
		for patch in patches:
			var bounds := Rect2i(patch[0], Vector2i.ONE)
			for tile: Vector2i in patch:
				bounds = bounds.expand(tile).expand(tile + Vector2i.ONE)
			assert_lte(
				maxi(bounds.size.x, bounds.size.y),
				4,
				"a ford of seed %d at %s is too long: %s" % [world_seed, patch[0], bounds.size]
			)


## The pieces `tiles` falls into, joined by the given steps: {tile: piece number}.
func _pieces(tiles: Array[Vector2i], steps: Array[Vector2i]) -> Dictionary[Vector2i, int]:
	var members := {}
	for tile in tiles:
		members[tile] = true
	var piece_of: Dictionary[Vector2i, int] = {}
	var pieces := 0
	for start in tiles:
		if piece_of.has(start):
			continue
		pieces += 1
		var open: Array[Vector2i] = [start]
		piece_of[start] = pieces
		while not open.is_empty():
			var tile: Vector2i = open.pop_back()
			for side in steps:
				if members.has(tile + side) and not piece_of.has(tile + side):
					piece_of[tile + side] = pieces
					open.append(tile + side)
	return piece_of


## How many different pieces of `piece_of` the tiles beside `patch` are in.
func _pieces_beside(patch: Array, piece_of: Dictionary[Vector2i, int]) -> int:
	var beside := {}
	for tile: Vector2i in patch:
		for side in World.CONNECTION_SIDES:
			if piece_of.has(tile + side):
				beside[piece_of[tile + side]] = true
	return beside.size()


## A ford cuts the creek in two and a walker crosses the creek over it, and nowhere else.
func test_a_ford_is_a_crossing_from_bank_to_bank() -> void:
	for world_seed in SEEDS_WITH_A_STEEP_BEND:
		var tiles := _creek_tiles(world_seed)
		var water: Array[Vector2i] = []
		for tile in tiles:
			if tiles[tile] != CreekLayout.Bed.FORD:
				water.append(tile)
		# Water touching only at a corner is one piece: a ford may take the tile between.
		var water_pieces := _pieces(water, EIGHT_STEPS)
		var river := RiverLine.new(world_seed)
		for patch in _ford_patches(tiles):
			var where := "the ford of seed %d at %s" % [world_seed, patch[0]]
			# Where the creek ends, at the river or at its source, the banks join round it.
			if absf(patch[0].y - river.line_y(patch[0].x)) < 14.0:
				continue
			var box := Rect2i(patch[0], Vector2i.ONE)
			for tile: Vector2i in patch:
				box = box.expand(tile)
			box = box.grow(8)
			var is_near_source := false
			var land: Array[Vector2i] = []
			var land_and_ford: Array[Vector2i] = []
			for x in range(box.position.x, box.end.x + 1):
				for y in range(box.position.y, box.end.y + 1):
					var tile := Vector2i(x, y)
					var bed: CreekLayout.Bed = tiles.get(tile, CreekLayout.Bed.NONE)
					is_near_source = is_near_source or bed == CreekLayout.Bed.SOURCE
					if bed == CreekLayout.Bed.NONE:
						land.append(tile)
					if bed == CreekLayout.Bed.NONE or bed == CreekLayout.Bed.FORD:
						land_and_ford.append(tile)
			if is_near_source:
				continue
			assert_eq(_pieces_beside(patch, water_pieces), 2, "%s cuts the water in two" % where)
			assert_eq(
				_pieces_beside(patch, _pieces(land, World.CONNECTION_SIDES)),
				2,
				"%s: the banks are apart" % where
			)
			assert_eq(
				_pieces_beside(patch, _pieces(land_and_ford, World.CONNECTION_SIDES)),
				1,
				"%s: the banks are joined" % where
			)


func test_a_ford_of_a_creek_running_east_to_west_is_across_it() -> void:
	var layout := _layout(1)
	var ford_tiles: Array[Vector2i] = []
	for x in range(70, 92):
		for y in range(-8, 6):
			if layout.bed_at(Vector2i(x, y)) == CreekLayout.Bed.FORD:
				ford_tiles.append(Vector2i(x, y))
	assert_gt(ford_tiles.size(), 0, "a ford near (80, -1)")
	for tile in ford_tiles:
		assert_lte(absi(tile.x - ford_tiles[0].x), 3, "a ford is no band: %s" % tile)


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


func test_the_generator_knows_its_fords_and_keeps_them_clear_of_reeds() -> void:
	var generator := WorldGenerator.new(SEEDS[0])
	var layout := _layout(SEEDS[0])
	var fords := 0
	for tile in _creek_tiles(SEEDS[0]):
		if tile.x < -240 or generator._river_distance(tile) < WorldGenerator.RIVER_HALF_WIDTH:
			continue
		var is_ford := layout.bed_at(tile) == CreekLayout.Bed.FORD
		assert_eq(generator.is_ford(tile), is_ford, str(tile))
		if is_ford:
			fords += 1
			assert_eq(generator.object_type_at(tile, generator.terrain_at(tile)), &"", str(tile))
	assert_gt(fords, 10, "fords checked")
