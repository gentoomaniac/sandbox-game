extends ResourceCase
## The scarecrow (task 226): made by hand, put down outdoors anywhere there is room, noting the day
## it was put down, taken down again for the item, and kept through a save.


func test_it_is_made_by_hand_from_what_the_land_gives() -> void:
	var rules := RecipeRules.default_rules()
	assert_has(rules.recipes_at(&""), ItemTypes.SCARECROW)
	var crafting := Crafting.new(_state)
	assert_eq(crafting.craft(ItemTypes.SCARECROW), Crafting.Result.MISSING_MATERIALS)
	for material in rules.materials(ItemTypes.SCARECROW):
		_state.player.inventory.add(material, rules.materials(ItemTypes.SCARECROW)[material])
	assert_eq(crafting.craft(ItemTypes.SCARECROW), Crafting.Result.CRAFTED)
	assert_eq(_count(ItemTypes.SCARECROW), 1)


func test_it_is_put_down_with_the_day_and_used_up() -> void:
	_state.clock.day = 7
	_state.player.inventory.add(ItemTypes.SCARECROW, 1)
	_hold(ItemTypes.SCARECROW)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE)
	var scarecrow := _world.object_at(_tile)
	assert_eq(scarecrow.type, WorldObjectTypes.SCARECROW)
	assert_eq(int(scarecrow.state["placed_day"]), 7)
	assert_eq(_count(ItemTypes.SCARECROW), 0)
	assert_false(_world.is_walkable(_tile))


func test_it_is_an_outdoor_object_not_put_down_on_water() -> void:
	_state.player.inventory.add(ItemTypes.SCARECROW, 1)
	_hold(ItemTypes.SCARECROW)
	_world.set_terrain(_tile, Tile.Terrain.WATER)
	assert_ne(_state.use_facing_tile(), ToolUse.Use.PLACE)
	var scarecrow_type: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.SCARECROW]
	assert_eq(scarecrow_type["placeable_in"], WorldObjectTypes.OUTDOORS)


func test_the_hammer_takes_it_down_for_the_item() -> void:
	_place(WorldObjectTypes.SCARECROW)
	var builder := Builder.new(_state)
	var target := builder.take_down_target(_tile)
	assert_eq(builder.take_down_gives(target), {ItemTypes.SCARECROW: 1})
	assert_true(builder.take_down(target))
	assert_null(_world.object_at(_tile))
	assert_eq(_count(ItemTypes.SCARECROW), 1)


func test_the_axe_takes_it_down_for_the_item() -> void:
	_place(WorldObjectTypes.SCARECROW)
	_hit(ItemTypes.RUSTY_IRON_AXE, WorldObjectTypes.TYPES[WorldObjectTypes.SCARECROW]["hp"])
	assert_null(_world.object_at(_tile))
	assert_eq(_dropped(ItemTypes.SCARECROW) + _count(ItemTypes.SCARECROW), 1)


func test_it_is_kept_through_a_save_with_its_day() -> void:
	var scarecrow := _place(WorldObjectTypes.SCARECROW)
	scarecrow.state["placed_day"] = 4
	_world.change_object(scarecrow)
	var kept := _through_save().world.object_at(_tile)
	assert_eq(kept.type, WorldObjectTypes.SCARECROW)
	assert_eq(int(kept.state["placed_day"]), 4)
