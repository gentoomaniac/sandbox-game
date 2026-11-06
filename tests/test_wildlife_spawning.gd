extends GutTest
## Where wildlife may appear (habitat, the ring around the view) and when it reacts to the player.

const SEED := 1

var _rules := WildlifeRules.default_rules()


func test_deer_need_a_forest_and_squirrels_trees() -> void:
	assert_false(_rules.is_habitat(WildlifeRules.DEER, Tile.Terrain.GRASS, 0, false))
	assert_true(_rules.is_habitat(WildlifeRules.DEER, Tile.Terrain.GRASS, 10, false))
	assert_false(_rules.is_habitat(WildlifeRules.SQUIRREL, Tile.Terrain.GRASS, 0, false))
	assert_true(_rules.is_habitat(WildlifeRules.SQUIRREL, Tile.Terrain.GRASS, 3, false))
	assert_false(_rules.is_habitat(WildlifeRules.DEER, Tile.Terrain.WATER, 10, false))


func test_ground_animals_stay_off_water() -> void:
	for kind in [WildlifeRules.BIRD, WildlifeRules.RABBIT, WildlifeRules.BUTTERFLY]:
		assert_false(_rules.is_habitat(kind, Tile.Terrain.WATER, 0, false), "%s on water" % kind)
		assert_true(_rules.is_habitat(kind, Tile.Terrain.GRASS, 0, false), "%s on grass" % kind)


func test_storks_hunt_on_wet_ground_and_on_grass_only_by_water() -> void:
	var stork := WildlifeRules.STORK
	assert_true(_rules.is_habitat(stork, Tile.Terrain.WETLAND, 0, true))
	assert_true(_rules.is_habitat(stork, Tile.Terrain.FLOODPLAIN, 0, true))
	assert_true(_rules.is_habitat(stork, Tile.Terrain.GRASS, 0, true), "a wet meadow")
	assert_false(_rules.is_habitat(stork, Tile.Terrain.GRASS, 0, false), "dry grass")
	assert_false(_rules.is_habitat(stork, Tile.Terrain.SOIL, 0, true), "a field")
	assert_false(_rules.is_habitat(stork, Tile.Terrain.WATER, 0, true))


func test_geese_graze_the_marsh_and_the_floodplain() -> void:
	var geese := WildlifeRules.GEESE
	assert_true(_rules.is_habitat(geese, Tile.Terrain.FLOODPLAIN, 0, true))
	assert_true(_rules.is_habitat(geese, Tile.Terrain.WETLAND, 0, true))
	assert_true(_rules.is_habitat(geese, Tile.Terrain.GRASS, 0, true), "the marsh, by its ditches")
	assert_false(_rules.is_habitat(geese, Tile.Terrain.GRASS, 0, false), "the dry Geest")
	assert_false(_rules.is_habitat(geese, Tile.Terrain.SOIL, 0, true), "a field")


func test_geese_graze_further_from_the_water_than_storks_hunt() -> void:
	var world := World.new(SEED)
	world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Vector2i(0, 0)))
	for y in range(0, 16):
		for x in range(0, 16):
			world.set_terrain(Vector2i(x, y), Tile.Terrain.GRASS)
	world.set_terrain(Vector2i(14, 8), Tile.Terrain.WATER)
	assert_true(_rules.is_habitat_at(WildlifeRules.GEESE, world, Vector2i(8, 8)))
	assert_false(_rules.is_habitat_at(WildlifeRules.STORK, world, Vector2i(8, 8)))


func test_water_is_looked_for_around_a_tile() -> void:
	var world := World.new(SEED)
	world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Vector2i(0, 0)))
	var origin := Vector2i(8, 8)
	for y in range(3, 14):
		for x in range(3, 14):
			world.set_terrain(Vector2i(x, y), Tile.Terrain.GRASS)
	assert_false(WildlifeRules.has_water_near(world, origin, 4))
	world.set_terrain(Vector2i(13, 8), Tile.Terrain.WATER)
	assert_false(WildlifeRules.has_water_near(world, origin, 4), "a pond beyond the radius")
	assert_true(WildlifeRules.has_water_near(world, origin, 5))
	world.set_terrain(Vector2i(6, 4), Tile.Terrain.WATER)
	assert_true(WildlifeRules.has_water_near(world, origin, 4), "a ditch within it")
	assert_false(WildlifeRules.has_water_near(world, origin, 0))
	world.set_terrain(Vector2i(6, 4), Tile.Terrain.SEA)
	assert_true(WildlifeRules.has_water_near(world, origin, 4), "a tideway within it")


func test_a_stork_is_at_home_on_a_wet_meadow_of_the_map_but_not_on_a_dry_one() -> void:
	var world := World.new(SEED)
	world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Vector2i(0, 0)))
	for y in range(0, 16):
		for x in range(0, 16):
			world.set_terrain(Vector2i(x, y), Tile.Terrain.GRASS)
	assert_false(_rules.is_habitat_at(WildlifeRules.STORK, world, Vector2i(8, 8)))
	world.set_terrain(Vector2i(10, 8), Tile.Terrain.WATER)
	assert_true(_rules.is_habitat_at(WildlifeRules.STORK, world, Vector2i(8, 8)))
	world.set_terrain(Vector2i(8, 8), Tile.Terrain.SOIL)
	assert_false(_rules.is_habitat_at(WildlifeRules.STORK, world, Vector2i(8, 8)), "a field")


func test_trees_are_counted_around_a_tile() -> void:
	var world := World.new(SEED)
	world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Vector2i(0, 0)))
	var origin := Vector2i(8, 8)
	var near := WildlifeRules.count_trees(world, origin, 2)
	var far := WildlifeRules.count_trees(world, origin, 7)
	assert_gte(far, near)
	assert_eq(WildlifeRules.count_trees(world, origin, 0), _tree_at(world, origin))


func _tree_at(world: World, pos: Vector2i) -> int:
	var object := world.object_at(pos)
	return 1 if object != null and WildlifeRules.TREE_TYPES.has(object.type) else 0


func test_spawn_points_lie_outside_the_view_or_at_its_edge() -> void:
	var view := Rect2(Vector2(100, 100), Vector2(320, 180))
	var player := view.get_center()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var inset := _rules.general("spawn_inset_tiles") * WildlifeRules.TILE_SIZE
	var margin := _rules.general("spawn_margin_tiles") * WildlifeRules.TILE_SIZE
	for _i in 300:
		var point := _rules.random_ring_point(view, rng)
		assert_true(view.grow(margin).has_point(point), "not beyond the margin")
		assert_false(view.grow(-inset).has_point(point), "not deep inside the view")
		assert_true(_rules.is_spawn_point(point, view, player))


func test_nothing_spawns_on_the_player_or_inside_the_view() -> void:
	var view := Rect2(Vector2(0, 0), Vector2(160, 90))
	assert_false(_rules.is_spawn_point(view.get_center(), view, view.get_center()))
	assert_false(_rules.is_spawn_point(Vector2(1000, 1000), view, view.get_center()))
	assert_true(_rules.is_spawn_point(Vector2(-20, 40), view, view.get_center()))
	# At the edge, but the player stands right there.
	assert_false(_rules.is_spawn_point(Vector2(-20, 40), view, Vector2(-20, 41)))


func test_animals_far_from_the_view_vanish() -> void:
	var view := Rect2(Vector2(0, 0), Vector2(320, 180))
	assert_false(_rules.is_beyond_view(Vector2(-50, 50), view))
	assert_true(_rules.is_beyond_view(Vector2(-1000, 50), view))


# --- Reacting to the player ---


func test_birds_and_rabbits_flee_at_their_distance() -> void:
	assert_eq(_rules.reaction(WildlifeRules.BIRD, 2.9), WildlifeRules.Reaction.FLEE)
	assert_eq(_rules.reaction(WildlifeRules.BIRD, 3.5), WildlifeRules.Reaction.NONE)
	assert_eq(_rules.reaction(WildlifeRules.RABBIT, 3.9), WildlifeRules.Reaction.FLEE)
	assert_eq(_rules.reaction(WildlifeRules.RABBIT, 4.5), WildlifeRules.Reaction.NONE)


func test_deer_look_up_at_6_tiles_and_bound_away_at_4() -> void:
	assert_eq(_rules.reaction(WildlifeRules.DEER, 7.0), WildlifeRules.Reaction.NONE)
	assert_eq(_rules.reaction(WildlifeRules.DEER, 5.0), WildlifeRules.Reaction.ALERT)
	assert_eq(_rules.reaction(WildlifeRules.DEER, 3.5), WildlifeRules.Reaction.FLEE)


func test_a_hunting_stork_flies_off_at_5_tiles_but_one_on_a_roof_never() -> void:
	assert_eq(_rules.reaction(WildlifeRules.STORK, 4.5), WildlifeRules.Reaction.FLEE)
	assert_eq(_rules.reaction(WildlifeRules.STORK, 6.0), WildlifeRules.Reaction.NONE)
	assert_eq(_rules.reaction(WildlifeRules.ROOF_STORK, 0.5), WildlifeRules.Reaction.NONE)


func test_geese_look_up_at_9_tiles_and_fly_off_at_6() -> void:
	assert_eq(_rules.reaction(WildlifeRules.GEESE, 10.0), WildlifeRules.Reaction.NONE)
	assert_eq(_rules.reaction(WildlifeRules.GEESE, 8.0), WildlifeRules.Reaction.ALERT)
	assert_eq(_rules.reaction(WildlifeRules.GEESE, 5.5), WildlifeRules.Reaction.FLEE)


func test_insects_ignore_the_player() -> void:
	assert_eq(_rules.reaction(WildlifeRules.BEE, 0.5), WildlifeRules.Reaction.NONE)
	assert_eq(_rules.reaction(WildlifeRules.BUTTERFLY, 0.5), WildlifeRules.Reaction.NONE)


func test_mice_live_by_farmland_and_frogs_by_the_water() -> void:
	var mouse := WildlifeRules.MOUSE
	assert_true(_rules.is_habitat(mouse, Tile.Terrain.SOIL, 0, false, true), "a field")
	assert_true(_rules.is_habitat(mouse, Tile.Terrain.GRASS, 0, false, true), "a hedge bank")
	assert_false(_rules.is_habitat(mouse, Tile.Terrain.GRASS, 0, false, false), "open grassland")
	assert_false(_rules.is_habitat(mouse, Tile.Terrain.WETLAND, 0, false, true))
	var frog := WildlifeRules.FROG
	assert_true(_rules.is_habitat(frog, Tile.Terrain.WETLAND, 0, true))
	assert_true(_rules.is_habitat(frog, Tile.Terrain.GRASS, 0, true), "by a ditch")
	assert_false(_rules.is_habitat(frog, Tile.Terrain.GRASS, 0, false), "dry grass")
	assert_false(_rules.is_habitat(frog, Tile.Terrain.SOIL, 0, true), "a field")


func test_farmland_is_looked_for_around_a_tile() -> void:
	var world := World.new(SEED)
	world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Vector2i(0, 0)))
	var origin := Vector2i(8, 8)
	for y in range(0, 16):
		for x in range(0, 16):
			world.set_terrain(Vector2i(x, y), Tile.Terrain.GRASS)
			world.remove_object(Vector2i(x, y))
	assert_false(WildlifeRules.has_farm_near(world, origin, 2))
	assert_false(_rules.is_habitat_at(WildlifeRules.MOUSE, world, origin))
	world.set_terrain(Vector2i(10, 9), Tile.Terrain.SOIL)
	assert_true(WildlifeRules.has_farm_near(world, origin, 2), "a field")
	assert_false(WildlifeRules.has_farm_near(world, origin, 1))
	assert_true(_rules.is_habitat_at(WildlifeRules.MOUSE, world, origin))
	world.set_terrain(Vector2i(10, 9), Tile.Terrain.GRASS)
	world.add_object(WorldObject.new(WorldObjectTypes.KNICK, Vector2i(6, 7)))
	assert_true(WildlifeRules.has_farm_near(world, origin, 2), "a Knick")
	world.remove_object(Vector2i(6, 7))
	world.add_object(WorldObject.new(WorldObjectTypes.STONE_WALL, Vector2i(7, 10)))
	assert_true(WildlifeRules.has_farm_near(world, origin, 2), "a fieldstone wall")
	world.remove_object(Vector2i(7, 10))
	world.place_building(BuildingTypes.KATE, Vector2i(9, 10))
	assert_true(WildlifeRules.has_farm_near(world, origin, 2), "a house")
