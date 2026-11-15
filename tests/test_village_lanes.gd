extends VillageCase
## The lanes and the town square of the village are worn to a path and stay so, walked or not
## (design/world/wehlsbuell.md, section 8).

const NIGHTS := 40


## A world of its own to run nights in, with the village built and its chunks as the build left them
## (not loaded).
func _fresh_world() -> World:
	var world := World.new(1)
	assert_eq(VillageBuilder.build(world, _site(1), _plan), "")
	return world


func _plan_tiles_of_lanes_and_square() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	tiles.append_array(_plan.all_lane_tiles().keys())
	for v in range(_plan.square.position.y, _plan.square.end.y):
		for u in range(_plan.square.position.x, _plan.square.end.x):
			tiles.append(Vector2i(u, v))
	return tiles


func _end_nights(world: World, nights: int) -> void:
	for _night in nights:
		world.end_wear_day()


func test_every_grass_tile_of_the_lanes_and_the_square_is_a_path_after_the_build() -> void:
	var world := _fresh_world()
	var kept := world.village.kept_worn_tiles
	assert_gt(kept.size(), 300)
	for plan_tile in _plan_tiles_of_lanes_and_square():
		var tile := _site(1).to_world(plan_tile)
		var wears := _terrain_at(1, plan_tile) in [Tile.Terrain.GRASS, Tile.Terrain.FLOODPLAIN]
		assert_eq(kept.has(tile), wears, "%s" % plan_tile)
		if wears:
			assert_eq(world.wear_stage(tile), PathRules.Stage.PATH, "%s" % plan_tile)


func test_a_tile_that_does_not_wear_is_not_kept() -> void:
	var world := _fresh_world()
	var warft_tiles := _plan.warft_tiles(_plan.warften[1])
	# The church's Warft lies under the end of the Kirchweg and the corner of the square.
	var warft_lane_tile := Vector2i(29, 7)
	assert_true(warft_tiles.has(warft_lane_tile))
	assert_false(world.village.kept_worn_tiles.has(_site(1).to_world(warft_lane_tile)))


func test_lanes_and_square_stay_worn_over_many_nights_loaded_or_not() -> void:
	var world := _fresh_world()
	var kept := world.village.kept_worn_tiles.duplicate()
	var elsewhere := _site(1).to_world(Vector2i(70, 40))
	world.wear.restore_days(elsewhere, PathRules.default_rules().most_days())

	_end_nights(world, NIGHTS)

	for tile in kept:
		assert_eq(world.wear_stage(tile), PathRules.Stage.PATH, "%s" % tile)
	assert_eq(
		world.wear_stage(elsewhere), PathRules.Stage.UNWORN, "ground that is not kept grows back"
	)


func test_a_way_laid_on_a_lane_wipes_its_wear_and_it_is_worn_again_when_the_way_is_taken_up(
) -> void:
	var world := _fresh_world()
	var tile := _site(1).to_world(Vector2i(30, 12))
	_load(world, _generator(1), tile)
	assert_true(world.village.kept_worn_tiles.has(tile))
	world.add_object(WorldObject.new(WorldObjectTypes.PLANK_WALK, tile))

	_end_nights(world, 3)
	assert_eq(world.wear_stage(tile), PathRules.Stage.UNWORN, "a way never wears")

	world.remove_object(tile)
	_end_nights(world, 1)
	assert_eq(world.wear_stage(tile), PathRules.Stage.PATH, "the lane is back")


func test_a_lane_tile_that_was_tilled_does_not_wear_again() -> void:
	var world := _fresh_world()
	var tile := _site(1).to_world(Vector2i(30, 12))
	_load(world, _generator(1), tile)
	world.set_terrain(tile, Tile.Terrain.SOIL)

	_end_nights(world, 2)

	assert_eq(world.wear_stage(tile), PathRules.Stage.UNWORN)
