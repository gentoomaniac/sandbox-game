extends OutcomeCase
## What the player did is told once, after it worked, with who, what, where and on which map, the
## object and the items: for every kind of action, from the screen and from code alike. A
## refusal and a loaded game tell nothing.

# --- Tool uses ---


func test_tilling_tells_where() -> void:
	_hold(ItemTypes.HOE)
	_state.use_facing_tile()
	_assert_one(ActionOutcome.TILL, _tile)


func test_planting_tells_the_seed_and_the_plant() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_state.player.inventory.add(ItemTypes.TURNIP_SEEDS, 3)
	_hold(ItemTypes.TURNIP_SEEDS)
	_state.use_facing_tile()
	_assert_one(
		ActionOutcome.PLANT,
		_tile,
		ItemTypes.TYPES[ItemTypes.TURNIP_SEEDS]["plants"],
		{ItemTypes.TURNIP_SEEDS: 1}
	)


func test_a_hit_that_does_not_finish_and_the_one_that_does_are_told_apart() -> void:
	_make_room()
	_place(WorldObjectTypes.STONE)
	_hold(ItemTypes.PICKAXE)
	_state.use_facing_tile()
	_assert_one(ActionOutcome.HIT, _tile, WorldObjectTypes.STONE)
	_outcomes.clear()
	while _outcomes.is_empty() or _outcomes.back().kind == ActionOutcome.HIT:
		_outcomes.clear()
		_state.use_facing_tile()
	assert_eq(_outcomes.size(), 1)
	assert_eq(_outcomes[0].kind, ActionOutcome.BREAK)
	assert_eq(_outcomes[0].object, WorldObjectTypes.STONE)
	assert_eq(_outcomes[0].items, {ItemTypes.STONE: _dropped(ItemTypes.STONE)})


func test_placing_and_taking_down_inside_a_house_tell_the_interior_as_the_map() -> void:
	var kate: Building = null
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := _state.player.tile() + Vector2i(x, y)
			if kate == null and _world.placement_blockers(BuildingTypes.KATE, origin).is_empty():
				kate = _world.place_building(BuildingTypes.KATE, origin)
	_state.player.position = Vector2(kate.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	_state.player.position = Vector2(3.5, 4.5)
	_state.player.facing = Vector2i.DOWN
	_state.player.inventory.add(ItemTypes.CHEST, 1)
	_hold(ItemTypes.CHEST)
	var target := _state.player.facing_tile()
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE)
	_assert_one(ActionOutcome.PLACE, target, WorldObjectTypes.CHEST, {ItemTypes.CHEST: 1})
	assert_true(_outcomes[0].map is Interior)
	_outcomes.clear()
	_hold(ItemTypes.AXE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.TAKE_DOWN)
	assert_eq(_outcomes[0].kind, ActionOutcome.TAKE_DOWN)


func test_eating_and_dropping_tell_the_item() -> void:
	_state.player.energy = 10.0
	_state.player.inventory.add(ItemTypes.BERRIES, 2)
	_hold(ItemTypes.BERRIES)
	assert_true(_state.eat_held())
	_assert_one(ActionOutcome.EAT, _state.player.tile(), &"", {ItemTypes.BERRIES: 1})
	_outcomes.clear()
	assert_true(_state.drop_from_inventory(_state.player.inventory.selected_slot))
	_assert_one(ActionOutcome.DROP, _state.player.facing_tile(), &"", {ItemTypes.BERRIES: 1})


func test_picking_up_tells_what_was_taken() -> void:
	_world.drop_items(_tile, {ItemTypes.LOGS: 3})
	for pile in _world.ground_items.all():
		pile.settle_seconds = 0.0
		_state.player.position = pile.position
		_state.collect_ground_items(0.1)
	var taken := 0
	for outcome in _outcomes:
		assert_eq(outcome.kind, ActionOutcome.PICK_UP)
		taken += outcome.items[ItemTypes.LOGS]
	assert_eq(taken, 3)
	assert_eq(_count(ItemTypes.LOGS), 3)


# --- Crafting and building ---


func _craft_planks(is_from_screen: bool) -> void:
	var workbench := _place_beside(WorldObjectTypes.WORKBENCH)
	_state.player.inventory.add(ItemTypes.LOGS, 1)
	var crafting := Crafting.new(_state)
	if is_from_screen:
		var screen := CraftingScreen.new()
		add_child_autofree(screen)
		screen.show_crafting(crafting, _state.player.inventory)
		screen.open_station(workbench)
		for row: RecipeRow in screen.find_children("*", "RecipeRow", true, false):
			if row.recipe_id == &"planks":
				row.pressed.emit()
	else:
		crafting.craft(&"planks", workbench)


func test_crafting_from_the_screen_and_from_code_gives_the_same_state_and_one_outcome() -> void:
	_craft_planks(true)
	var from_screen := _state.player.inventory.totals()
	_assert_one(
		ActionOutcome.CRAFT,
		_tile + Vector2i.RIGHT,
		WorldObjectTypes.WORKBENCH,
		{ItemTypes.PLANKS: 2}
	)
	_state.player.inventory.remove(ItemTypes.PLANKS, 2)
	_state.player.skills.set_points(&"woodworking", 0.0)
	_outcomes.clear()
	_world.remove_object(_tile + Vector2i.RIGHT)
	_craft_planks(false)
	assert_eq(_state.player.inventory.totals(), from_screen)
	_assert_one(
		ActionOutcome.CRAFT,
		_tile + Vector2i.RIGHT,
		WorldObjectTypes.WORKBENCH,
		{ItemTypes.PLANKS: 2}
	)


func test_starting_a_firing_and_taking_the_bricks_out_are_two_outcomes() -> void:
	var kiln := _place(WorldObjectTypes.KILN)
	_state.player.inventory.add(ItemTypes.RAW_BRICK, 6)
	_state.player.inventory.add(ItemTypes.LOGS, 2)
	var crafting := Crafting.new(_state)
	assert_eq(crafting.craft(&"bricks", kiln), Crafting.Result.STARTED)
	assert_eq(_outcomes.size(), 1)
	assert_eq(_outcomes[0].kind, ActionOutcome.START_CRAFT)
	assert_eq(_outcomes[0].object, WorldObjectTypes.KILN)
	_outcomes.clear()
	_state.simulation.advance(12 * GameClock.MINUTES_PER_HOUR)
	assert_eq(crafting.take_out(kiln), Crafting.Result.TAKEN_OUT)
	assert_eq(_outcomes.size(), 1)
	assert_eq(_outcomes[0].kind, ActionOutcome.TAKE_OUT)
	assert_eq(_outcomes[0].items, {ItemTypes.BRICK: 6})


func test_building_and_demolishing_tell_the_building_and_the_materials() -> void:
	var builder := Builder.new(_state)
	builder.choose(BuildingTypes.SHACK)
	for item: StringName in builder.costs():
		_state.player.inventory.add(item, builder.costs()[item])
	var origin := Vector2i.ZERO
	var building: Building = null
	for y in range(2, 20):
		for x in range(-10, 10):
			if (
				building == null
				and (
					_world
					. placement_blockers(BuildingTypes.SHACK, _tile + Vector2i(x, y))
					. is_empty()
				)
			):
				origin = _tile + Vector2i(x, y)
				building = builder.place(origin)
	assert_not_null(building, "room for a shack near the camp")
	_assert_one(ActionOutcome.BUILD, origin, BuildingTypes.SHACK, builder.costs())
	_outcomes.clear()
	assert_true(builder.take_down(TakeDownTarget.of_building(building)))
	assert_eq(_outcomes.size(), 1)
	assert_eq(_outcomes[0].kind, ActionOutcome.DEMOLISH)
	assert_eq(_outcomes[0].object, BuildingTypes.SHACK)
	assert_eq(_outcomes[0].items, _state.refund_of_building(building))


# --- Nothing for a refusal or a load ---


func test_refusals_tell_nothing() -> void:
	_place(WorldObjectTypes.PINE)
	_hold(ItemTypes.AXE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NEEDS_BETTER_TOOL)
	assert_eq(_state.use_tile(_tile + Vector2i(0, 5)), ToolUse.Use.OUT_OF_REACH)
	_hold(ItemTypes.HOE)
	_state.player.energy = _state.player.attributes.max_energy()
	assert_false(_state.eat_held())
	var workbench := _place_beside(WorldObjectTypes.WORKBENCH)
	_state.player.inventory.add(ItemTypes.RAW_BRICK, 6)
	_state.player.inventory.add(ItemTypes.LOGS, 2)
	assert_eq(Crafting.new(_state).craft(&"bricks", workbench), Crafting.Result.WRONG_STATION)
	assert_false(_state.drop_from_inventory(Inventory.SLOT_COUNT))
	assert_eq(_outcomes, [] as Array[ActionOutcome])


func test_loading_a_game_tells_nothing() -> void:
	_world.drop_items(_tile, {ItemTypes.LOGS: 3})
	_place_beside(WorldObjectTypes.WORKBENCH)
	var restored := _through_save()
	var told: Array[ActionOutcome] = []
	restored.action_done.connect(func(outcome: ActionOutcome) -> void: told.append(outcome))
	restored.collect_ground_items(0.1)
	restored.walk(Vector2.ZERO, 0.1, 1.0)
	assert_eq(told, [] as Array[ActionOutcome])
