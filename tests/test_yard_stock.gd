extends ResourceCase
## The trough and the hay rack of the farm yard (task 122): made at the workbench, put down
## outdoors on two tiles, and each holds a stock that shows in one of four pictures by how full it
## is.

const STOCK_TYPES: Array[StringName] = [WorldObjectTypes.TROUGH, WorldObjectTypes.HAY_RACK]


func test_the_workbench_makes_the_trough_and_the_hay_rack_from_planks_and_logs() -> void:
	var rules := RecipeRules.default_rules()
	assert_eq(rules.materials(&"trough"), {ItemTypes.PLANKS: 5, ItemTypes.LOGS: 1})
	assert_eq(rules.materials(&"hay_rack"), {ItemTypes.PLANKS: 4, ItemTypes.LOGS: 2})
	for recipe_id in [&"trough", &"hay_rack"]:
		assert_true(rules.recipes_at(&"workbench").has(recipe_id))
		assert_eq(rules.skill(recipe_id), &"woodworking")


func test_each_is_put_down_outdoors_on_two_tiles_empty_and_blocks_the_way() -> void:
	for type in STOCK_TYPES:
		_world.remove_object(_tile)
		_world.remove_object(_tile + Vector2i.RIGHT)
		var item := ItemTypes.item_placing(type)
		_state.player.inventory.add(item, 1)
		_hold(item)
		assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE, str(type))
		var placed := _world.object_at(_tile + Vector2i.RIGHT)
		assert_eq(placed.type, type)
		assert_eq(placed.pos, _tile)
		assert_eq(ObjectStock.units(placed), 0, "it starts empty")
		assert_false(_world.is_walkable(_tile + Vector2i.RIGHT))


func test_the_axe_takes_each_down_and_it_drops_the_item() -> void:
	_state.player.inventory.add(ItemTypes.AXE, 1)
	for type in STOCK_TYPES:
		_clear_ground()
		_place(type)
		_hit(ItemTypes.AXE, WorldObjectTypes.TYPES[type]["hp"])
		assert_null(_world.object_at(_tile))
		assert_eq(_dropped(ItemTypes.item_placing(type)), 1, str(type))


func test_the_picture_follows_the_fill_fraction_in_four_steps() -> void:
	var trough := _place(WorldObjectTypes.TROUGH)
	var capacity := ObjectStock.capacity(trough)
	assert_eq(capacity, 100)
	var fractions := {0: 0, 1: 1, 34: 1, 35: 2, 69: 2, 70: 3, 100: 3}
	for units: int in fractions:
		trough.state["stock"] = units
		assert_eq(ObjectStock.look(trough), fractions[units], "%d of %d" % [units, capacity])
		assert_eq(ObjectTileset.atlas_cell(trough).x, fractions[units])


func test_the_atlas_has_the_four_pictures_of_each_in_its_row() -> void:
	for type in STOCK_TYPES:
		var object_type: Dictionary = WorldObjectTypes.TYPES[type]
		assert_eq(ObjectTileset.looks_count(object_type), WorldObjectTypes.STOCK_LOOKS)


func test_a_stock_is_filled_up_to_its_capacity_and_emptied_to_nothing() -> void:
	var rack := _place(WorldObjectTypes.HAY_RACK)
	assert_eq(ObjectStock.add(rack, 60), 60)
	assert_eq(ObjectStock.add(rack, 60), 40, "only what fits")
	assert_eq(ObjectStock.units(rack), 100)
	assert_eq(ObjectStock.take(rack, 30), 30)
	assert_eq(ObjectStock.take(rack, 300), 70, "only what is there")
	assert_eq(ObjectStock.units(rack), 0)


func test_the_stock_is_saved_with_the_object() -> void:
	ObjectStock.add(_place(WorldObjectTypes.TROUGH), 45)
	assert_eq(ObjectStock.units(_through_save().world.object_at(_tile)), 45)


func test_a_pour_of_the_can_puts_ten_units_of_water_into_the_trough_up_to_its_capacity() -> void:
	var trough := _place(WorldObjectTypes.TROUGH)
	_hold(ItemTypes.WATERING_CAN)
	var can_before := _state.player.can_water
	assert_eq(_state.use_facing_tile(), ToolUse.Use.POUR)
	assert_eq(ObjectStock.units(trough), YardRules.default_rules().pour_units())
	assert_eq(_state.player.can_water, can_before - 1)
	for _pour in 9:
		assert_eq(_state.use_facing_tile(), ToolUse.Use.POUR)
	assert_eq(ObjectStock.units(trough), 100)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING, "a full trough takes no more")
	assert_eq(_state.player.can_water, can_before - 10)


func test_an_empty_can_pours_nothing_and_says_so() -> void:
	var trough := _place(WorldObjectTypes.TROUGH)
	_hold(ItemTypes.WATERING_CAN)
	_state.player.can_water = 0
	assert_eq(_state.use_facing_tile(), ToolUse.Use.CAN_EMPTY)
	assert_eq(ObjectStock.units(trough), 0)


func test_pouring_costs_the_energy_of_watering_and_tells_the_trough() -> void:
	var outcomes: Array[ActionOutcome] = []
	_state.action_done.connect(func(outcome: ActionOutcome) -> void: outcomes.append(outcome))
	_place(WorldObjectTypes.TROUGH)
	_hold(ItemTypes.WATERING_CAN)
	_state.player.energy = 50.0
	_state.cheats.is_weight_off = true
	_state.use_facing_tile()
	assert_almost_eq(_state.player.energy, 50.0 - _state.energy_rules.cost_of(&"water"), 0.0001)
	assert_eq(outcomes.size(), 1)
	assert_eq(outcomes[0].kind, ActionOutcome.WATER)
	assert_eq(outcomes[0].object, WorldObjectTypes.TROUGH)


func test_the_can_pours_into_a_trough_and_not_into_a_hay_rack() -> void:
	var rack := _place(WorldObjectTypes.HAY_RACK)
	_hold(ItemTypes.WATERING_CAN)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)
	assert_eq(ObjectStock.units(rack), 0)


func test_the_trough_shows_what_was_poured_in() -> void:
	var trough := _place(WorldObjectTypes.TROUGH)
	_hold(ItemTypes.WATERING_CAN)
	_state.use_facing_tile()
	assert_eq(ObjectStock.look(trough), 1)
	for _pour in 3:
		_state.use_facing_tile()
	assert_eq(ObjectStock.look(trough), 2)
	for _pour in 3:
		_state.use_facing_tile()
	assert_eq(ObjectStock.look(trough), 3)


func test_a_hay_item_puts_its_feed_units_into_the_hay_rack_and_is_used_up() -> void:
	var rack := _place(WorldObjectTypes.HAY_RACK)
	_state.player.inventory.add(ItemTypes.HAY, 3)
	_hold(ItemTypes.HAY)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.FEED)
	assert_eq(ObjectStock.units(rack), YardRules.default_rules().feed_units(ItemTypes.HAY))
	assert_eq(_count(ItemTypes.HAY), 2)
	assert_eq(ObjectStock.look(rack), 1)


func test_a_full_hay_rack_takes_no_more_hay() -> void:
	var rack := _place(WorldObjectTypes.HAY_RACK)
	ObjectStock.add(rack, 100)
	_state.player.inventory.add(ItemTypes.HAY, 3)
	_hold(ItemTypes.HAY)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)
	assert_eq(_count(ItemTypes.HAY), 3, "the hay is kept")


func test_hay_goes_into_the_rack_only_and_other_things_are_not_feed() -> void:
	_place(WorldObjectTypes.TROUGH)
	_state.player.inventory.add(ItemTypes.HAY, 1)
	_hold(ItemTypes.HAY)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING, "not into a trough")
	_world.remove_object(_tile)
	_place(WorldObjectTypes.HAY_RACK)
	_state.player.inventory.add(ItemTypes.REEDS, 1)
	_hold(ItemTypes.REEDS)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING, "reeds are no feed")
	assert_eq(YardRules.default_rules().feed_units(ItemTypes.REEDS), 0)


func test_feeding_tells_the_rack_and_the_feed_and_is_heard() -> void:
	var outcomes: Array[ActionOutcome] = []
	_state.action_done.connect(func(outcome: ActionOutcome) -> void: outcomes.append(outcome))
	_place(WorldObjectTypes.HAY_RACK)
	_state.player.inventory.add(ItemTypes.HAY, 1)
	_hold(ItemTypes.HAY)
	_state.use_facing_tile()
	assert_eq(outcomes.size(), 1)
	assert_eq(outcomes[0].kind, ActionOutcome.FEED)
	assert_eq(outcomes[0].object, WorldObjectTypes.HAY_RACK)
	assert_eq(outcomes[0].items, {ItemTypes.HAY: 1})
	assert_ne(SoundEvents.action(ActionOutcome.FEED), &"")
