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
