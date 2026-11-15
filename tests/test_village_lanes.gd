extends VillageCase
## The lanes and the town square of the village are laid with cobbles at the start, the same cobble
## ways the player lays (design/world/wehlsbuell.md, section 8).

## The bits of a connection mask (see World `connections`).
const SOUTH := 4
const EAST := 2
const WEST := 8


func _plan_tiles_of_lanes_and_square() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	tiles.append_array(_plan.all_lane_tiles().keys())
	for v in range(_plan.square.position.y, _plan.square.end.y):
		for u in range(_plan.square.position.x, _plan.square.end.x):
			tiles.append(Vector2i(u, v))
	return tiles


func _is_cobble(world_seed: int, plan_tile: Vector2i) -> bool:
	var object := _object_at(world_seed, plan_tile)
	return object != null and object.type == WorldObjectTypes.STONE_PATH


func test_every_lane_and_square_tile_that_is_free_ground_has_a_cobble() -> void:
	for world_seed: int in SEEDS:
		var cobbled := 0
		for plan_tile in _plan_tiles_of_lanes_and_square():
			var tile := _site(world_seed).to_world(plan_tile)
			if _is_cobble(world_seed, plan_tile):
				cobbled += 1
				continue
			var object := _object_at(world_seed, plan_tile)
			var terrain := _terrain_at(world_seed, plan_tile)
			var reason := "%s of seed %d" % [plan_tile, world_seed]
			assert_true(
				(
					object != null
					or _world(world_seed).building_at(tile) != null
					or (
						terrain
						not in [Tile.Terrain.GRASS, Tile.Terrain.WARFT, Tile.Terrain.FLOODPLAIN]
					)
				),
				"a free tile with no cobble: " + reason
			)
		assert_gt(cobbled, 350, "seed %d" % world_seed)


func test_no_cobble_lies_under_a_building_or_beside_the_door_it_would_shut() -> void:
	for world_seed: int in SEEDS:
		for plan_tile in _plan_tiles_of_lanes_and_square():
			if _is_cobble(world_seed, plan_tile):
				var tile := _site(world_seed).to_world(plan_tile)
				assert_null(_world(world_seed).building_at(tile), "%s" % plan_tile)


func test_the_cobbles_of_a_lane_join_up_and_end_where_it_does() -> void:
	var world := _world(1)
	var site := _site(1)
	var middle := world.object_at(site.to_world(Vector2i(20, 12)))
	assert_eq(world.connections(middle), EAST | WEST)
	var corner := world.object_at(site.to_world(Vector2i(57, -12)))
	assert_eq(world.connections(corner), SOUTH | WEST)


func test_the_cobbles_do_not_wear_or_turn_to_grass_over_the_nights() -> void:
	var world := _world(1)
	var tile := _site(1).to_world(Vector2i(20, 12))
	for _night in 40:
		world.end_wear_day()
	assert_eq(world.wear_stage(tile), PathRules.Stage.UNWORN)
	assert_eq(world.object_at(tile).type, WorldObjectTypes.STONE_PATH)
