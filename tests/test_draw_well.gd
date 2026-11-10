extends ResourceCase
## The draw well of the farm yard (task 122): made at the workbench, put down outdoors, it stands
## in the way, and the pickaxe takes it up again.


func test_the_masons_workbench_makes_the_well_from_stone_planks_logs_and_fibre() -> void:
	var rules := RecipeRules.default_rules()
	assert_true(rules.recipes_at(&"workbench").has(&"draw_well"))
	assert_eq(rules.skill(&"draw_well"), &"masonry")
	assert_eq(
		rules.materials(&"draw_well"),
		{ItemTypes.STONE: 12, ItemTypes.PLANKS: 3, ItemTypes.LOGS: 2, ItemTypes.FIBRE: 2}
	)


func test_a_well_is_put_down_outdoors_and_blocks_the_way() -> void:
	_state.player.inventory.add(ItemTypes.DRAW_WELL, 1)
	_hold(ItemTypes.DRAW_WELL)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.DRAW_WELL)
	assert_false(_world.is_walkable(_tile))
	assert_eq(_count(ItemTypes.DRAW_WELL), 0)


func test_the_pickaxe_takes_the_well_up_again() -> void:
	_place(WorldObjectTypes.DRAW_WELL)
	_state.player.inventory.add(ItemTypes.PICKAXE, 1)
	var hits := WorldObjectTypes.TYPES[WorldObjectTypes.DRAW_WELL]["hp"] as int
	_hit(ItemTypes.PICKAXE, hits)
	assert_null(_world.object_at(_tile))
	assert_eq(_dropped(ItemTypes.DRAW_WELL), 1)
