extends GutTest
## The camp site is always on free, buildable land, and the same for the same seed.

const SEEDS: Array[int] = [1, 2, 3, 42, 1337, 99999]


func _create(world_seed: int) -> CampSite:
	return CampSite.create(World.new(world_seed), WorldGenerator.new(world_seed))


func test_the_whole_clearing_is_buildable_and_holds_only_the_camp() -> void:
	var camp_types := [WorldObjectTypes.FIREPLACE, WorldObjectTypes.SLEEPING_BAG]
	for world_seed in SEEDS:
		var world := World.new(world_seed)
		var camp := CampSite.create(world, WorldGenerator.new(world_seed))
		var reach := CampSite.CLEARING_SIZE / 2
		for y in range(-reach, reach + 1):
			for x in range(-reach, reach + 1):
				var pos := camp.fireplace_pos + Vector2i(x, y)
				var message := "seed %d: %s" % [world_seed, pos]
				assert_true(world.tile_at(pos).is_buildable(), message)
				var object := world.object_at(pos)
				assert_true(object == null or object.type in camp_types, message)


func test_places_a_fireplace_and_a_sleeping_bag_and_spawns_on_walkable_ground() -> void:
	for world_seed in SEEDS:
		var world := World.new(world_seed)
		var camp := CampSite.create(world, WorldGenerator.new(world_seed))
		assert_eq(world.object_at(camp.fireplace_pos).type, WorldObjectTypes.FIREPLACE)
		assert_eq(world.object_at(camp.sleeping_bag_pos).type, WorldObjectTypes.SLEEPING_BAG)
		assert_true(world.is_walkable(camp.spawn_pos), "seed %d" % world_seed)
		assert_false(world.is_walkable(camp.fireplace_pos))


func test_is_deterministic() -> void:
	for world_seed in SEEDS:
		assert_eq(_create(world_seed).fireplace_pos, _create(world_seed).fireplace_pos)


func test_is_near_the_world_centre() -> void:
	for world_seed in SEEDS:
		var centre := _create(world_seed).fireplace_pos
		assert_lt(maxi(absi(centre.x), absi(centre.y)), 40, "seed %d" % world_seed)
