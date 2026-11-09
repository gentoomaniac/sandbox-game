extends ResourceCase
## The woodworker's recipes at the workbench: planks, a stool for the house, a grave marker for
## the churchyard, a piece of jetty, clogs, a rowing boat, the carved chest, which holds more
## than the plain one, and the joined cupboard, the master's piece.


func test_the_workbench_makes_the_woodworkers_recipes_in_rising_levels() -> void:
	var rules := RecipeRules.default_rules()
	var recipes := rules.recipes_at(&"workbench").filter(
		func(recipe_id: StringName) -> bool: return rules.skill(recipe_id) == &"woodworking"
	)
	assert_eq(
		recipes,
		[
			&"planks",
			&"stool",
			&"grave_marker",
			&"jetty",
			&"clogs",
			&"rowing_boat",
			&"carved_chest",
			&"cupboard",
		]
	)
	var levels := recipes.map(func(recipe_id: StringName) -> float: return rules.level(recipe_id))
	assert_eq(levels, [0.0, 10.0, 15.0, 20.0, 25.0, 35.0, 45.0, 70.0])


func test_a_log_makes_two_planks_and_teaches_woodworking() -> void:
	_state.player.inventory.add(ItemTypes.LOGS, 1)
	assert_eq(Crafting.new(_state).craft(&"planks"), Crafting.Result.CRAFTED)
	assert_eq(_count(ItemTypes.PLANKS), 2)
	assert_eq(_state.player.skills.points(&"woodworking"), 2.0)


func test_a_stool_is_placed_only_inside_a_house() -> void:
	_state.player.inventory.add(ItemTypes.STOOL, 1)
	_hold(ItemTypes.STOOL)
	assert_eq(_state.use_at(_tile), ToolUse.Use.NOTHING, "it has no picture for outdoors")


func test_a_grave_marker_stands_outdoors_and_the_pickaxe_takes_it_up_again() -> void:
	_state.player.inventory.add(ItemTypes.GRAVE_MARKER, 1)
	_hold(ItemTypes.GRAVE_MARKER)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.GRAVE)
	var grave: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.GRAVE]
	assert_eq(grave["placeable_in"], WorldObjectTypes.OUTDOORS)
	_state.player.inventory.add(ItemTypes.PICKAXE, 1)
	_hit(ItemTypes.PICKAXE, 2)
	assert_eq(_dropped(ItemTypes.GRAVE_MARKER), 1)


func test_the_carved_chest_holds_twenty_slots_and_the_storage_screen_shows_them() -> void:
	var carved := _place(WorldObjectTypes.CARVED_CHEST)
	assert_eq(carved.storage.slots.size(), 20)
	var screen := StorageScreen.new(autofree(HotbarCase.new_hotbar()))
	add_child_autofree(screen)
	screen.open_chest(carved, _state.player)
	var views := screen.find_children("*", "SlotView", true, false)
	assert_eq(views.size(), Inventory.BACKPACK_SIZE + 20 + 1, "with the trash can")
	screen.close()
	screen.open_chest(
		WorldObject.new(WorldObjectTypes.CHEST, _tile + Vector2i.RIGHT), _state.player
	)
	views = screen.find_children("*", "SlotView", true, false)
	assert_eq(views.size(), Inventory.BACKPACK_SIZE + 15 + 1, "a plain chest again")


func test_the_joined_cupboard_stands_only_in_a_house_and_holds_twenty_five_slots() -> void:
	_state.player.inventory.add(ItemTypes.CUPBOARD, 1)
	_hold(ItemTypes.CUPBOARD)
	assert_eq(_state.use_at(_tile), ToolUse.Use.NOTHING)
	assert_eq(WorldObject.new(WorldObjectTypes.CUPBOARD, _tile).storage.slots.size(), 25)
