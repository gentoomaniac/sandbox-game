extends ResourceCase
## The ways the player lays (#62): a plank walk and a stone path, crafted, put down a piece a tile,
## taken up again with the axe or the pickaxe for the piece, and kept through a save.

const WAYS := {
	ItemTypes.PLANK_WALK: WorldObjectTypes.PLANK_WALK,
	ItemTypes.STONE_PATH: WorldObjectTypes.STONE_PATH,
}
const TOOLS := {
	WorldObjectTypes.PLANK_WALK: ItemTypes.RUSTY_IRON_AXE,
	WorldObjectTypes.STONE_PATH: ItemTypes.RUSTY_IRON_PICKAXE,
}


func _lay(type: StringName) -> WorldObject:
	_world.remove_object(_tile)
	return _place(type)


func test_a_plank_walk_is_made_at_the_workbench_and_a_stone_path_by_hand() -> void:
	var rules := RecipeRules.default_rules()
	assert_has(rules.recipes_at(&"workbench"), ItemTypes.PLANK_WALK)
	assert_eq(rules.skill(ItemTypes.PLANK_WALK), &"woodworking")
	assert_has(rules.recipes_at(&""), ItemTypes.STONE_PATH)
	assert_eq(rules.skill(ItemTypes.STONE_PATH), &"masonry")


func test_crafting_takes_the_materials_and_gives_the_pieces() -> void:
	var workbench := _place_beside(WorldObjectTypes.WORKBENCH)
	var rules := RecipeRules.default_rules()
	_state.player.skills.set_points(&"woodworking", 10.0)
	_state.player.skills.set_points(&"masonry", 10.0)
	for item in WAYS:
		var station := workbench if rules.station_of(item) == &"workbench" else null
		for material in rules.materials(item):
			_state.player.inventory.add(material, rules.materials(item)[material])
		assert_eq(Crafting.new(_state).craft(item, station), Crafting.Result.CRAFTED, item)
		assert_eq(_count(item), rules.count(item), item)


func test_a_piece_is_never_worth_more_than_it_cost() -> void:
	var rules := RecipeRules.default_rules()
	for item in WAYS:
		var drops: Dictionary = WorldObjectTypes.TYPES[WAYS[item]]["drops"]
		assert_eq(drops, {item: 1}, "taking a piece up gives the piece")
		assert_gte(rules.count(item), 1)


func test_each_way_is_put_down_on_grass_and_used_up() -> void:
	for item in WAYS:
		_world.remove_object(_tile)
		_state.player.inventory.add(item, 1)
		_hold(item)
		assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE, str(item))
		assert_eq(_world.object_at(_tile).type, WAYS[item])
		assert_eq(_count(item), 0)


func test_a_way_is_walked_on_and_not_in_the_way_of_the_player() -> void:
	for type in WAYS.values():
		_lay(type)
		assert_true(_world.is_walkable(_tile), str(type))


func test_no_way_goes_on_water_tilled_soil_or_an_occupied_tile() -> void:
	for item in WAYS:
		_state.player.inventory.add(item, 1)
		_hold(item)
		for terrain in [Tile.Terrain.WATER, Tile.Terrain.SOIL]:
			_world.set_terrain(_tile, terrain)
			assert_ne(_state.use_facing_tile(), ToolUse.Use.PLACE, "%s on %s" % [item, terrain])
		_world.set_terrain(_tile, Tile.Terrain.GRASS)
		_place(WorldObjectTypes.CHEST)
		assert_ne(_state.use_facing_tile(), ToolUse.Use.PLACE, "%s on a chest" % item)
		_world.remove_object(_tile)


func test_planks_go_on_mud_and_stone_does_not() -> void:
	_world.set_terrain(_tile, Tile.Terrain.MUD)
	_state.player.inventory.add(ItemTypes.PLANK_WALK, 1)
	_state.player.inventory.add(ItemTypes.STONE_PATH, 1)
	_hold(ItemTypes.STONE_PATH)
	assert_ne(_state.use_facing_tile(), ToolUse.Use.PLACE)
	_hold(ItemTypes.PLANK_WALK)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE)


func test_a_way_is_not_tilled() -> void:
	_lay(WorldObjectTypes.STONE_PATH)
	assert_eq(_hit(ItemTypes.RUSTY_IRON_HOE, 1), ToolUse.Use.NOTHING)


func test_the_tool_takes_a_way_up_for_the_piece() -> void:
	for type in TOOLS:
		_clear_ground()
		_lay(type)
		_hit(TOOLS[type], WorldObjectTypes.TYPES[type]["hp"])
		assert_null(_world.object_at(_tile), str(type))
		assert_eq(_dropped(WorldObjectTypes.TYPES[type]["drops"].keys()[0]), 1, str(type))


func test_the_wrong_tool_leaves_a_way() -> void:
	_lay(WorldObjectTypes.STONE_PATH)
	assert_eq(_hit(ItemTypes.RUSTY_IRON_AXE, 1), ToolUse.Use.NOTHING)


func test_a_way_is_taken_up_from_under_the_player() -> void:
	_lay(WorldObjectTypes.STONE_PATH)
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	assert_false(ToolUse.new(_state).is_standing_on(_world.object_at(_tile)))


func test_ways_are_kept_through_a_save() -> void:
	for type in WAYS.values():
		_lay(type)
		assert_eq(_through_save().world.object_at(_tile).type, type)


func test_a_way_is_never_worn_by_steps() -> void:
	for type in WAYS.values():
		_lay(type)
		_world.wear_tile(_tile, 100.0)
		_world.end_wear_day()
		assert_eq(_world.wear_stage(_tile), PathRules.Stage.UNWORN, str(type))
		_world.set_wear_days(_tile, PathRules.default_rules().path_after_days())
		assert_eq(_world.wear_stage(_tile), PathRules.Stage.UNWORN, str(type))


func test_grass_next_to_a_way_still_wears() -> void:
	_lay(WorldObjectTypes.STONE_PATH)
	_world.wear_tile(_tile + Vector2i.LEFT, 100.0)
	_world.end_wear_day()
	assert_eq(_world.wear_stage(_tile + Vector2i.LEFT), PathRules.Stage.UNWORN, "one day")
	_world.set_wear_days(_tile + Vector2i.LEFT, PathRules.default_rules().path_after_days())
	assert_eq(_world.wear_stage(_tile + Vector2i.LEFT), PathRules.Stage.PATH)


func test_laying_a_way_clears_the_wear_beneath_and_draws_the_tile_again() -> void:
	_world.set_wear_days(_tile, PathRules.default_rules().path_after_days())
	_world.wear_tile(_tile, 3.0)
	watch_signals(_world)
	_lay(WorldObjectTypes.PLANK_WALK)
	assert_signal_emitted_with_parameters(_world, "tile_changed", [_tile])
	assert_eq(_world.wear_stage(_tile), PathRules.Stage.UNWORN)
	assert_true(_world.wear_steps().is_empty())
	_world.remove_object(_tile)
	assert_eq(_world.wear_stage(_tile), PathRules.Stage.UNWORN, "grass again once taken up")


func test_a_way_is_never_mud() -> void:
	_lay(WorldObjectTypes.STONE_PATH)
	_world.set_muddy(true)
	assert_false(_world.is_muddy_at(_tile))


func test_the_player_walks_a_way_a_bit_faster_also_in_the_rain() -> void:
	var rules := PathRules.default_rules()
	_world.set_muddy(true)
	for type in WAYS.values():
		_lay(type)
		_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
		assert_eq(_state.travel.walk_speed_factor(_state), rules.way_walk_factor(), str(type))
	assert_gt(rules.way_walk_factor(), 1.0)
