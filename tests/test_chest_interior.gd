extends GutTest
## The chest inside a house: where it can be placed, taking it down, opening it, and saving it
## with the building's interior.

const SEED := 7

var _state: GameState
var _kate: Building
var _interior: Interior


func before_each() -> void:
	_state = GameState.new()
	_state.world = World.new(SEED)
	_state.world.add_chunk(Chunk.new(Vector2i.ZERO))
	_state.player.home_map = _state.world
	_state.player.inventory.add(ItemTypes.CHEST, 3)
	_state.player.inventory.add(ItemTypes.AXE, 1)
	_kate = _state.world.place_building(BuildingTypes.KATE, Vector2i(2, 2))
	_stand_on(_kate.door_tile())
	_state.pass_door()
	_interior = _state.current_map as Interior
	_stand_on(Vector2i(3, 4))
	_state.player.facing = Vector2i.DOWN


func _stand_on(tile: Vector2i) -> void:
	_state.player.position = Vector2(tile) + Vector2(0.5, 0.5)


func _hold(item: StringName) -> void:
	_state.player.inventory.select(
		_state.player.inventory.slots.find_custom(
			func(stack: Dictionary) -> bool: return stack.get("item") == item
		)
	)


# --- Placing ---


func test_a_chest_goes_on_free_floor() -> void:
	assert_true(_interior.is_placeable(Vector2i(3, 5)))
	assert_true(_interior.is_placeable(Vector2i(2, 3)))


func test_a_chest_does_not_go_on_a_wall_furniture_the_exit_or_the_tile_inside_it() -> void:
	assert_false(_interior.is_placeable(Vector2i(0, 0)), "a wall")
	assert_false(_interior.is_placeable(Vector2i(4, 1)), "the back wall face")
	assert_false(_interior.is_placeable(Vector2i(1, 2)), "the bed")
	assert_false(_interior.is_placeable(Vector2i(5, 5)), "the table")
	assert_false(_interior.is_placeable(_interior.exit_tile), "the exit")
	assert_false(_interior.is_placeable(_interior.entry_tile()), "the entry tile")
	assert_false(_interior.is_placeable(Vector2i(20, 20)), "outside the room")


func test_using_the_chest_item_inside_puts_a_chest_on_the_tile_in_front() -> void:
	_hold(ItemTypes.CHEST)
	assert_eq(_state.use_at(Vector2i(3, 5)), ToolUse.Use.PLACE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE)
	assert_eq(_interior.object_at(Vector2i(3, 5)).type, WorldObjectTypes.CHEST)
	assert_eq(_state.player.inventory.count_of(ItemTypes.CHEST), 2)


func test_using_the_chest_item_on_furniture_or_a_wall_does_nothing() -> void:
	_hold(ItemTypes.CHEST)
	assert_eq(_state.use_at(Vector2i(5, 5)), ToolUse.Use.NOTHING)
	assert_eq(_state.use_at(Vector2i(0, 4)), ToolUse.Use.NOTHING)
	assert_eq(_state.player.inventory.count_of(ItemTypes.CHEST), 3)


func test_a_chest_is_not_placed_where_the_player_stands() -> void:
	_hold(ItemTypes.CHEST)
	assert_eq(_state.use_at(Vector2i(3, 4)), ToolUse.Use.NOTHING)


func test_other_items_do_nothing_inside() -> void:
	_state.player.inventory.add(ItemTypes.TURNIP_SEEDS, 2)
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_at(Vector2i(3, 5)), ToolUse.Use.NOTHING)


# --- Taking down ---


func _place_chest_in_front() -> WorldObject:
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i(3, 5))
	chest.storage.add(ItemTypes.LOGS, 12)
	_interior.add_object(chest)
	return chest


func test_the_axe_takes_a_chest_inside_down_into_the_inventory_with_what_it_held() -> void:
	_place_chest_in_front()
	_hold(ItemTypes.AXE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.TAKE_DOWN)
	assert_null(_interior.object_at(Vector2i(3, 5)))
	assert_eq(_state.player.inventory.count_of(ItemTypes.CHEST), 4)
	assert_eq(_state.player.inventory.count_of(ItemTypes.LOGS), 12)


func test_a_chest_inside_stays_when_the_inventory_has_no_room_for_it() -> void:
	var chest := _place_chest_in_front()
	for slot in Inventory.SLOT_COUNT:
		_state.player.inventory.slots[slot] = {"item": ItemTypes.AXE, "count": 1}
	_hold(ItemTypes.AXE)
	assert_eq(_state.use_at(Vector2i(3, 5)), ToolUse.Use.NO_ROOM)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NO_ROOM)
	assert_eq(_interior.object_at(Vector2i(3, 5)), chest)
	assert_eq(chest.storage.count_of(ItemTypes.LOGS), 12)


func test_the_axe_does_nothing_to_other_furniture() -> void:
	_hold(ItemTypes.AXE)
	assert_eq(_state.use_at(Vector2i(5, 5)), ToolUse.Use.NOTHING)


# --- Opening ---


func test_e_opens_the_targeted_chest_even_with_a_bed_in_reach() -> void:
	_stand_on(Vector2i(2, 3))
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i(3, 4))
	_interior.add_object(chest)
	assert_not_null(_state.bed_in_reach())
	assert_eq(Interaction.chest_to_open(_state, Vector2i(3, 4)), chest)


func test_e_sleeps_when_the_chest_in_reach_is_not_the_target() -> void:
	_stand_on(Vector2i(2, 3))
	_interior.add_object(WorldObject.new(WorldObjectTypes.CHEST, Vector2i(3, 4)))
	assert_null(Interaction.chest_to_open(_state, Vector2i(2, 4)))


func test_the_chest_in_the_room_of_a_house_opens_with_no_bed_in_reach() -> void:
	var chest := _place_chest_in_front()
	assert_null(_state.bed_in_reach())
	assert_eq(Interaction.chest_to_open(_state, Vector2i(3, 5)), chest)


# --- Saving ---


func _through_save() -> GameState:
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Vector2i.ZERO))
	return restored


func test_a_chest_placed_inside_is_saved_with_the_interior_and_what_it_holds() -> void:
	_hold(ItemTypes.CHEST)
	_state.use_facing_tile()
	_interior.object_at(Vector2i(3, 5)).storage.add(ItemTypes.STONE, 40)
	_interior.object_at(Vector2i(3, 5)).storage.add(ItemTypes.TURNIP, 3)
	var restored := _through_save()
	var restored_interior := restored.current_map as Interior
	assert_ne(restored_interior, restored.world)
	var chest := restored_interior.object_at(Vector2i(3, 5))
	assert_eq(chest.type, WorldObjectTypes.CHEST)
	assert_eq(chest.storage.totals(), {ItemTypes.STONE: 40, ItemTypes.TURNIP: 3})


func test_the_chest_of_the_map_holds_what_is_put_in_it_too() -> void:
	var chest := _interior.objects().filter(
		func(object: WorldObject) -> bool: return object.type == WorldObjectTypes.CHEST
	)
	assert_eq(chest.size(), 1, "the Kate has a chest of its own")
	assert_eq(chest[0].storage.slots.size(), 15)
	chest[0].storage.add(ItemTypes.LOGS, 5)
	var restored := _through_save()
	var restored_chests := (restored.current_map as Interior).objects().filter(
		func(object: WorldObject) -> bool: return object.type == WorldObjectTypes.CHEST
	)
	assert_eq(restored_chests[0].storage.count_of(ItemTypes.LOGS), 5)
