extends ResourceCase
## The stations the player places (the workbench first): crafted by hand, placed like a chest
## outdoors and in a house, opened with E, and taken down again.


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
