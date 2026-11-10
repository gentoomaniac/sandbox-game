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


func _empty_the_can() -> void:
	_state.player.can_water = 0
	_hold(ItemTypes.WATERING_CAN)


func test_the_can_is_filled_at_the_well() -> void:
	_place(WorldObjectTypes.DRAW_WELL)
	_empty_the_can()
	assert_eq(_state.use_facing_tile(), ToolUse.Use.FILL_CAN)
	assert_eq(_state.player.can_water, EnergyRules.default_rules().can_capacity())


func test_a_full_can_takes_no_more_water_at_the_well() -> void:
	_place(WorldObjectTypes.DRAW_WELL)
	_hold(ItemTypes.WATERING_CAN)
	assert_eq(_state.player.can_water, EnergyRules.default_rules().can_capacity())
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)


func test_the_can_is_filled_from_fresh_water_and_not_from_the_sea() -> void:
	_empty_the_can()
	_world.set_terrain(_tile, Tile.Terrain.WATER)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.FILL_CAN, "a river, a pond or a ditch")
	_state.player.can_water = 0
	_world.set_terrain(_tile, Tile.Terrain.SEA)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING, "the sea is salt")
	_world.set_terrain(_tile, Tile.Terrain.MUD)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING, "the mud of the flats")
	_world.set_terrain(_tile, Tile.Terrain.SALT_MARSH)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING, "the salt marsh")
	assert_eq(_state.player.can_water, 0)


func test_filling_the_can_tells_the_well_or_the_water() -> void:
	var outcomes: Array[ActionOutcome] = []
	_state.action_done.connect(func(outcome: ActionOutcome) -> void: outcomes.append(outcome))
	_place(WorldObjectTypes.DRAW_WELL)
	_empty_the_can()
	_state.use_facing_tile()
	assert_eq(outcomes.size(), 1)
	assert_eq(outcomes[0].kind, ActionOutcome.FILL_CAN)
	assert_eq(outcomes[0].object, WorldObjectTypes.DRAW_WELL)
	assert_eq(SoundEvents.action(ActionOutcome.FILL_CAN), &"water_pour")


func test_watering_soil_takes_one_water_from_the_can() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_world.set_moisture(_tile, 0.0)
	_hold(ItemTypes.WATERING_CAN)
	var capacity := EnergyRules.default_rules().can_capacity()
	assert_eq(_state.use_facing_tile(), ToolUse.Use.WATER)
	assert_eq(_state.player.can_water, capacity - 1)


func test_an_empty_can_waters_nothing_and_says_so() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_world.set_moisture(_tile, 0.0)
	_empty_the_can()
	_state.player.energy = 50.0
	assert_eq(_state.use_facing_tile(), ToolUse.Use.CAN_EMPTY)
	assert_eq(_world.moisture_at(_tile), 0.0)
	assert_eq(_state.player.energy, 50.0, "no work was done")
	assert_eq(SoundEvents.failed_use(ToolUse.Use.CAN_EMPTY, ItemTypes.WATERING_CAN), &"denied")


func test_the_water_in_the_can_is_saved() -> void:
	_state.player.can_water = 7
	assert_eq(_through_save().player.can_water, 7)


func test_the_hotbar_shows_the_water_in_the_can_on_the_can_and_follows_it() -> void:
	var hotbar: HotbarHud = autofree(HotbarCase.new_hotbar(_state.player.inventory))
	add_child_autofree(hotbar)
	var can_slot := _state.player.inventory.slots.find_custom(
		func(stack: Dictionary) -> bool: return stack.get("item") == ItemTypes.WATERING_CAN
	)
	var views: Array[SlotView] = hotbar._slot_views
	assert_eq(views[can_slot].badge, str(EnergyRules.default_rules().can_capacity()))
	_state.player.can_water = 3
	assert_eq(views[can_slot].badge, "3")
	for slot in Inventory.HOTBAR_SIZE:
		if slot != can_slot:
			assert_eq(views[slot].badge, "", "only the can shows water")
