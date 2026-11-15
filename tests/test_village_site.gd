extends GutTest
## Where the village stands: found from the seed alone, on land that fits its plan, and the camp
## can walk there (design/world/wehlsbuell.md, section 2).

const SEEDS := [1, 4, 8, 13]
## The camp has this many tiles around its spawn tile that must be clear of the village.
const CAMP_CLEARANCE := 6


func test_a_site_is_found_and_is_the_same_every_time() -> void:
	for world_seed: int in SEEDS:
		var site := VillageSite.find(world_seed)
		assert_not_null(site, "seed %d" % world_seed)
		assert_eq(VillageSite.find(world_seed).origin, site.origin, "seed %d" % world_seed)


func test_other_seeds_have_other_sites() -> void:
	var origins := {}
	for world_seed: int in SEEDS:
		origins[VillageSite.find(world_seed).origin] = true
	assert_eq(origins.size(), SEEDS.size())


func test_the_origin_is_the_first_land_tile_east_of_the_salt_marsh() -> void:
	for world_seed: int in SEEDS:
		var generator := WorldGenerator.new(world_seed)
		var origin := VillageSite.find(world_seed).origin
		assert_eq(generator.terrain_at(origin + Vector2i.LEFT), Tile.Terrain.SALT_MARSH)
		assert_eq(generator.terrain_at(origin), Tile.Terrain.GRASS)


func test_the_land_inland_of_the_dyke_has_no_water_and_the_landing_stands_on_salt_marsh() -> void:
	var plan := VillagePlan.default_plan()
	for world_seed: int in SEEDS:
		var generator := WorldGenerator.new(world_seed)
		var site := VillageSite.find(world_seed)
		for v in range(plan.area.position.y, plan.area.end.y):
			for u in range(plan.inland_from_u, plan.area.end.x):
				var terrain := generator.terrain_at(site.to_world(Vector2i(u, v)))
				assert_true(
					terrain == Tile.Terrain.GRASS or terrain == Tile.Terrain.WETLAND,
					"seed %d, tile %s is %s" % [world_seed, Vector2i(u, v), terrain]
				)
		for tile in plan.warft_tiles(plan.warften[0]):
			assert_eq(generator.terrain_at(site.to_world(tile)), Tile.Terrain.SALT_MARSH)


func test_the_coast_of_the_village_rows_stays_near_the_dyke_of_the_middle_row() -> void:
	var plan := VillagePlan.default_plan()
	for world_seed: int in SEEDS:
		var generator := WorldGenerator.new(world_seed)
		var site := VillageSite.find(world_seed)
		for v in range(plan.area.position.y, plan.area.end.y):
			var dyke_x := generator.first_land_x(site.origin.y + v)
			assert_lte(absi(dyke_x - site.origin.x), VillageSite.COAST_TOLERANCE)


func test_the_camp_stands_on_the_side_of_the_river_that_the_village_does() -> void:
	for world_seed: int in SEEDS:
		var river := RiverLine.new(world_seed)
		var camp := CampSite.spawn_of_seed(world_seed)
		var site := VillageSite.find(world_seed)
		assert_eq(camp.y < river.line_y(camp.x), site.origin.y < river.line_y(site.origin.x))


func test_no_site_where_the_coast_is_never_straight_enough() -> void:
	var plan := VillagePlan.from_file(VillagePlan.DEFAULT_PATH)
	plan.area = Rect2i(plan.area.position, Vector2i(plan.area.size.x, 1500))
	assert_null(VillageSite.find(1, plan))


func test_no_dyke_stands_in_the_land_inland_of_the_dyke() -> void:
	# The sea dyke can stand a few tiles east of the first land (issue #94): on 40 seeds it never
	# reaches into the village's inland land.
	var plan := VillagePlan.default_plan()
	for world_seed in 40:
		var generator := WorldGenerator.new(world_seed)
		var site := VillageSite.find(world_seed)
		if site == null:
			continue
		for v in range(plan.area.position.y, plan.area.end.y):
			for u in range(plan.inland_from_u, plan.area.end.x):
				var tile := site.to_world(Vector2i(u, v))
				var type := generator.object_type_at(tile, generator.terrain_at(tile))
				assert_ne(
					type, WorldObjectTypes.DYKE, "seed %d, tile %s" % [world_seed, Vector2i(u, v)]
				)


func test_the_camp_does_not_stand_on_the_villages_land() -> void:
	var plan := VillagePlan.default_plan()
	for world_seed: int in SEEDS:
		var camp := CampSite.spawn_of_seed(world_seed)
		var site := VillageSite.find(world_seed)
		assert_false(site.land(plan).grow(CAMP_CLEARANCE).has_point(camp), "seed %d" % world_seed)
