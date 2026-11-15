extends GutTest
## The dykes WorldGenerator lays along the coast and the floodplain's edge (issue #94): a thin
## line of tiles joined on their sides, which runs on the diagonal where the edge slants (see
## LineSlants) with no gap at a step, and the land behind the sea dyke is never under the tide.

const SEEDS: Array[int] = [1, 7, 42, 99]
const ROWS := Vector2i(-300, 300)
const COLUMNS := Vector2i(-250, 700)
## Rows and columns this near the river's mouth are left out: there the river's dykes meet the
## sea dyke.
const MOUTH_CLEARANCE := 16.0

var _rules := LandscapeRules.default_rules()


func _dykes_in(generator: WorldGenerator, area: Rect2i) -> Dictionary[Vector2i, bool]:
	var dykes: Dictionary[Vector2i, bool] = {}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var tile := Vector2i(x, y)
			if generator.object_type_at(tile, generator.terrain_at(tile)) == WorldObjectTypes.DYKE:
				dykes[tile] = true
	return dykes


func _sides_joined(tile: Vector2i, dykes: Dictionary[Vector2i, bool]) -> int:
	var joined := 0
	for side in World.CONNECTION_SIDES:
		joined += int(dykes.has(tile + side))
	return joined


## The columns of the coast the sea dyke can stand in.
func _coast_columns() -> Vector2i:
	var line_x: float = _rules.value("coast", "line_x")
	var wander: float = _rules.value("coast", "wander")
	return Vector2i(
		floori(line_x - wander), ceili(line_x + wander + WorldGenerator.DYKE_LINE_REACH)
	)


func _is_near_the_river(generator: WorldGenerator, tile: Vector2i) -> bool:
	return generator._river_distance(tile) < WorldGenerator.DYKE_PROBE_DISTANCE + MOUTH_CLEARANCE


func test_the_sea_dyke_is_one_unbroken_line_of_tiles_joined_on_two_sides() -> void:
	var columns := _coast_columns()
	for world_seed in SEEDS:
		var generator := WorldGenerator.new(world_seed)
		var area := Rect2i(columns.x, ROWS.x - 1, columns.y - columns.x, ROWS.y - ROWS.x + 2)
		var dykes := _dykes_in(generator, area)
		for y in range(ROWS.x, ROWS.y):
			var row_tiles: Array[Vector2i] = []
			for x in range(columns.x, columns.y):
				var tile := Vector2i(x, y)
				if dykes.has(tile) and not _is_near_the_river(generator, tile):
					row_tiles.append(tile)
			if row_tiles.is_empty():
				continue
			var joins_next_row := false
			for tile in row_tiles:
				assert_eq(
					_sides_joined(tile, dykes),
					2,
					"a line, no block: %s, seed %d" % [tile, world_seed]
				)
				joins_next_row = joins_next_row or dykes.has(tile + Vector2i.DOWN)
			var next := row_tiles[0] + Vector2i.DOWN
			if not _is_near_the_river(generator, next):
				assert_true(joins_next_row, "no gap below row %d, seed %d" % [y, world_seed])


func test_the_river_dykes_are_lines_that_begin_and_end_cleanly() -> void:
	for world_seed in SEEDS:
		var generator := WorldGenerator.new(world_seed)
		var river := RiverLine.new(world_seed)
		var ends := 0
		var tiles := 0
		for x in range(COLUMNS.x, COLUMNS.y, 50):
			var middle := roundi(river.line_y(x))
			var area := Rect2i(x, middle - 30, 50, 60)
			var dykes := _dykes_in(generator, area)
			for tile in dykes:
				var is_inside := (
					tile.x > area.position.x
					and tile.x < area.end.x - 1
					and tile.y > area.position.y
					and tile.y < area.end.y - 1
				)
				if not is_inside:
					continue
				var joined := _sides_joined(tile, dykes)
				tiles += 1
				ends += int(joined == 1)
				assert_between(joined, 1, 2, "a line: %s, seed %d" % [tile, world_seed])
		assert_gt(tiles, 200, "river dykes in seed %d" % world_seed)
		assert_lt(ends, tiles / 20, "few ends: stretches, not pieces, in seed %d" % world_seed)


func test_the_land_behind_the_sea_dyke_is_dry_and_the_dyke_stands_on_land() -> void:
	var columns := _coast_columns()
	for world_seed in SEEDS:
		var generator := WorldGenerator.new(world_seed)
		for y in range(ROWS.x, ROWS.y, 3):
			var behind := false
			for x in range(columns.x - 40, columns.y + 10):
				var tile := Vector2i(x, y)
				var terrain := generator.terrain_at(tile)
				var is_dyke := generator.object_type_at(tile, terrain) == WorldObjectTypes.DYKE
				if is_dyke:
					assert_true(
						(
							terrain
							in [Tile.Terrain.GRASS, Tile.Terrain.WETLAND, Tile.Terrain.FLOODPLAIN]
						),
						"the dyke on land at %s, seed %d" % [tile, world_seed]
					)
				if behind and terrain != Tile.Terrain.WATER:
					assert_false(
						terrain in [Tile.Terrain.MUD, Tile.Terrain.SALT_MARSH, Tile.Terrain.SEA],
						"no tide behind the dyke at %s, seed %d" % [tile, world_seed]
					)
				behind = behind or is_dyke
