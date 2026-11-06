extends ResourceCase
## The stations the player places (workbench, kiln, oven): crafted by hand, placed like a
## chest (the kiln only outdoors), opened with E, and taken down again.


func _hold_placed(item: StringName) -> void:
	_state.player.inventory.add(item, 1)
	_hold(item)


## A game with the player inside a Kate, holding `item` and an axe.
func _inside_a_house(item: StringName) -> GameState:
	var state := GameState.new()
	state.world = World.new(SEED)
	state.world.add_chunk(Chunk.new(Vector2i.ZERO))
	state.player.home_map = state.world
	var kate := state.world.place_building(BuildingTypes.KATE, Vector2i(2, 2))
	state.player.position = Vector2(kate.door_tile()) + Vector2(0.5, 0.5)
	state.pass_door()
	state.player.position = Vector2(3.5, 4.5)
	state.player.inventory.add(ItemTypes.AXE, 1)
	state.player.inventory.add(item, 1)
	_select(state, item)
	return state


func _select(state: GameState, item: StringName) -> void:
	var inventory := state.player.inventory
	inventory.select(
		inventory.slots.find_custom(
			func(stack: Dictionary) -> bool: return stack.get("item") == item
		)
	)


func test_the_workbench_is_made_by_hand_from_logs() -> void:
	var rules := RecipeRules.default_rules()
	assert_has(rules.recipes_at(&""), &"workbench")
	_state.player.inventory.add(ItemTypes.LOGS, 6)
	assert_eq(Crafting.new(_state).craft(&"workbench"), Crafting.Result.CRAFTED)
	assert_eq(_count(ItemTypes.WORKBENCH), 1)


func test_a_workbench_is_placed_outdoors_and_e_opens_its_menu() -> void:
	_hold_placed(ItemTypes.WORKBENCH)
	assert_eq(_state.use_tile(_tile), ToolUse.Use.PLACE)
	var bench := _world.object_at(_tile)
	assert_eq(bench.type, WorldObjectTypes.WORKBENCH)
	assert_eq(Interaction.object_to_open(_state, _tile), bench)
	assert_eq(StationRules.default_rules().station_of(bench.type), &"workbench")


func test_a_workbench_outdoors_is_taken_down_with_the_axe() -> void:
	_place(WorldObjectTypes.WORKBENCH)
	_state.player.inventory.add(ItemTypes.AXE, 1)
	_hit(ItemTypes.AXE, 3)
	assert_null(_world.object_at(_tile))
	assert_eq(_dropped(ItemTypes.WORKBENCH), 1)


func test_a_workbench_goes_in_a_house_and_the_axe_takes_it_back_into_the_inventory() -> void:
	var state := _inside_a_house(ItemTypes.WORKBENCH)
	var tile := Vector2i(3, 5)
	assert_eq(state.use_tile(tile), ToolUse.Use.PLACE)
	assert_eq(state.current_map.object_at(tile).type, WorldObjectTypes.WORKBENCH)
	assert_eq(state.player.inventory.count_of(ItemTypes.WORKBENCH), 0)
	_select(state, ItemTypes.AXE)
	assert_eq(state.use_tile(tile), ToolUse.Use.TAKE_DOWN)
	assert_null(state.current_map.object_at(tile))
	assert_eq(state.player.inventory.count_of(ItemTypes.WORKBENCH), 1)


func test_the_furniture_of_a_house_is_not_taken_down() -> void:
	var state := _inside_a_house(ItemTypes.WORKBENCH)
	_select(state, ItemTypes.AXE)
	assert_eq(state.use_at(Vector2i(5, 5)), ToolUse.Use.NOTHING, "the table")


func test_a_kiln_is_made_by_hand_and_stands_only_outdoors() -> void:
	assert_has(RecipeRules.default_rules().recipes_at(&""), &"kiln")
	_hold_placed(ItemTypes.KILN)
	assert_eq(_state.use_at(_tile), ToolUse.Use.PLACE)
	var state := _inside_a_house(ItemTypes.KILN)
	assert_eq(state.use_at(Vector2i(3, 5)), ToolUse.Use.NOTHING, "its fire would burn the house")


func test_a_kiln_is_broken_down_with_the_pickaxe() -> void:
	_place(WorldObjectTypes.KILN)
	_state.player.inventory.add(ItemTypes.PICKAXE, 1)
	_hit(ItemTypes.PICKAXE, 4)
	assert_eq(_dropped(ItemTypes.KILN), 1)


func test_a_bake_oven_stands_outdoors_and_in_a_house() -> void:
	_hold_placed(ItemTypes.OVEN)
	assert_eq(_state.use_at(_tile), ToolUse.Use.PLACE)
	var state := _inside_a_house(ItemTypes.OVEN)
	assert_eq(state.use_at(Vector2i(3, 5)), ToolUse.Use.PLACE)
	assert_eq(StationRules.default_rules().station_of(WorldObjectTypes.OVEN), &"oven")
