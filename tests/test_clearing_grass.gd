extends ResourceCase
## Tall grass gives way: the hoe, planting and building remove it, standing or mown, without
## hay.


func before_each() -> void:
	super.before_each()
	_set_midsummer()


func _place_grass(mown := false) -> WorldObject:
	var grass := _place(WorldObjectTypes.TALL_GRASS)
	if mown:
		grass.pick()
	return grass


func test_the_hoe_tills_a_tile_with_tall_grass_and_removes_the_grass() -> void:
	for mown in [false, true]:
		_place_grass(mown)
		assert_eq(_hit(ItemTypes.RUSTY_IRON_HOE, 1), ToolUse.Use.TILL, "mown: %s" % mown)
		assert_eq(_world.tile_at(_tile).terrain, Tile.Terrain.SOIL)
		assert_null(_world.object_at(_tile))
		_world.set_terrain(_tile, Tile.Terrain.GRASS)
	assert_eq(_dropped(ItemTypes.HAY), 0, "clearing gives no hay")


func test_a_tree_seed_plants_on_a_tile_with_tall_grass_and_removes_the_grass() -> void:
	_place_grass()
	_hold(ItemTypes.ACORN)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLANT)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SAPLING)
	assert_eq(_dropped(ItemTypes.HAY), 0)


func test_crop_seeds_plant_on_tilled_ground_where_grass_was() -> void:
	_place_grass()
	_hit(ItemTypes.RUSTY_IRON_HOE, 1)
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLANT)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.TURNIP)


func test_the_cleared_grass_stays_gone_through_the_chunk_and_save() -> void:
	_place_grass()
	_hit(ItemTypes.RUSTY_IRON_HOE, 1)
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	_reload_chunk()
	assert_null(_world.object_at(_tile))
	assert_null(_through_save().world.object_at(_tile))


func test_other_objects_still_block_the_hoe() -> void:
	_place(WorldObjectTypes.SHRUB)
	assert_eq(_hit(ItemTypes.RUSTY_IRON_HOE, 1), ToolUse.Use.NOTHING)


func test_a_building_goes_up_over_tall_grass_and_clears_it() -> void:
	var world := World.new(1)
	world.clock.day = MIDSUMMER
	world.add_chunk(Chunk.new(Vector2i.ZERO))
	var house := BuildingTypes.KATE
	var origin := Vector2i(2, 2)
	var covered := Building.footprint_tiles(house, origin)
	for pos in covered:
		world.add_object(WorldObject.new(WorldObjectTypes.TALL_GRASS, pos))
	world.object_at(covered[0]).pick()
	assert_true(world.placement_blockers(house, origin).is_empty(), "the ghost is valid")
	assert_true(world.is_buildable(covered[0]))
	assert_not_null(world.place_building(house, origin))
	for pos in covered:
		assert_null(world.object_at(pos))
	world.clock.day = 1
	world.clock.day = MIDSUMMER
	for pos in covered:
		assert_null(world.object_at(pos), "it does not come back")
