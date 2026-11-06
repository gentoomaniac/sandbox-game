extends GutTest
## The coast of WorldGenerator: the open sea in the west, the tidal mud with its tideways, the
## salt marsh, and the sea dyke on the first tiles of the land; nothing of it near the camp.

const SEED := 42
const FORESHORE: Array[Tile.Terrain] = [Tile.Terrain.MUD, Tile.Terrain.SALT_MARSH]
## The area looked at: the coast line wanders around x = -260 (data/landscape.cfg).
const WEST := -700
const EAST := -150

var _generator := WorldGenerator.new(SEED)


## The first tile of a row, from the west, after which the next 10 are all land (or the river).
func _land_start(y: int) -> int:
	var land_run := 0
	for x in range(WEST, EAST):
		var terrain := _generator.terrain_at(Vector2i(x, y))
		var is_foreshore := terrain in FORESHORE or terrain == Tile.Terrain.SEA
		land_run = 0 if is_foreshore else land_run + 1
		if land_run == 10:
			return x - 9
	fail_test("row %d has no land" % y)
	return EAST


func test_the_far_west_is_open_sea() -> void:
	for y in range(-1000, 1000, 50):
		assert_eq(_generator.terrain_at(Vector2i(-1000, y)), Tile.Terrain.SEA, "row %d" % y)


func test_the_foreshore_has_mud_tideways_and_salt_marsh() -> void:
	var seen := {}
	var tideway_tiles := 0
	for y in range(-200, 200, 3):
		for x in range(-450, -200):
			var terrain := _generator.terrain_at(Vector2i(x, y))
			seen[terrain] = true
			var is_tideway := (
				(
					terrain == Tile.Terrain.SEA
					and _generator.terrain_at(Vector2i(x - 1, y)) == Tile.Terrain.MUD
				)
				or (
					terrain == Tile.Terrain.SEA
					and _generator.terrain_at(Vector2i(x, y - 1)) == Tile.Terrain.MUD
				)
			)
			tideway_tiles += int(is_tideway)
	assert_true(seen.has(Tile.Terrain.MUD), "mud")
	assert_true(seen.has(Tile.Terrain.SALT_MARSH), "salt marsh")
	assert_gt(tideway_tiles, 50, "water beside mud: tideways")


func test_the_sea_dyke_stands_on_the_first_land_of_every_row_but_for_the_river() -> void:
	for y in range(-300, 300, 5):
		var x := _land_start(y)
		var salt_marsh := _generator.terrain_at(Vector2i(x - 1, y))
		if salt_marsh != Tile.Terrain.SALT_MARSH:
			continue  # The river runs out here.
		var has_dyke := false
		for first_land in [Vector2i(x, y), Vector2i(x + 1, y)]:
			var terrain := _generator.terrain_at(first_land)
			has_dyke = (
				has_dyke or _generator.object_type_at(first_land, terrain) == WorldObjectTypes.DYKE
			)
		assert_true(has_dyke, "a dyke at x %d, row %d" % [x, y])


func test_all_the_mud_is_reached_on_foot_from_the_salt_marsh() -> void:
	var area := Rect2i(-480, -120, 300, 240)
	var walkable: Dictionary[Vector2i, bool] = {}
	var reached: Dictionary[Vector2i, bool] = {}
	var open: Array[Vector2i] = []
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var tile := Vector2i(x, y)
			var terrain := _generator.terrain_at(tile)
			walkable[tile] = terrain != Tile.Terrain.SEA and terrain != Tile.Terrain.WATER
			if terrain == Tile.Terrain.SALT_MARSH:
				reached[tile] = true
				open.append(tile)
	while not open.is_empty():
		var tile: Vector2i = open.pop_back()
		for side in World.CONNECTION_SIDES:
			var next := tile + side
			if walkable.get(next, false) and not reached.has(next):
				reached[next] = true
				open.append(next)
	var cut_off := 0
	for tile in walkable:
		if walkable[tile] and not reached.has(tile) and area.grow(-20).has_point(tile):
			cut_off += int(_generator.terrain_at(tile) == Tile.Terrain.MUD)
	# A lone tile or two may lie out in the sea, where its edge wanders: a sandbank.
	assert_lt(cut_off, 5, "mud tiles cut off by the tideways")


func test_the_land_around_the_camp_is_no_foreshore() -> void:
	var reach := CampSite.MAX_SEARCH_RADIUS * 2
	for y in range(-reach, reach, 4):
		for x in range(-reach, reach, 4):
			assert_false(_generator.terrain_at(Vector2i(x, y)) in FORESHORE, "%d, %d" % [x, y])


func test_the_sea_is_water_that_is_not_walked_on() -> void:
	var sea := Tile.new()
	sea.terrain = Tile.Terrain.SEA
	assert_false(sea.is_walkable())
	assert_eq(TerrainTileset.terrain_layer(Tile.Terrain.SEA, 0.0), TerrainTileset.Layer.WATER)
