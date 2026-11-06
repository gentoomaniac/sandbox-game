extends ResourceCase
## The hammer taking down: X switches the mode, the target is a building or a thing the player
## placed, and what each gives.

var _builder: Builder


func before_each() -> void:
	super.before_each()
	_builder = Builder.new(_state)


## A top left tile near the camp where the shack can be placed.
func _open_origin() -> Vector2i:
	for y in range(-24, 25):
		for x in range(-24, 25):
			var origin := _state.player.tile() + Vector2i(x, y)
			if _world.placement_blockers(BuildingTypes.SHACK, origin).is_empty():
				return origin
	fail_test("no room for a shack near the camp")
	return Vector2i.ZERO


func _place_a_chest() -> WorldObject:
	var chest := WorldObject.new(WorldObjectTypes.CHEST, _tile)
	chest.storage.add(ItemTypes.TURNIP, 4)
	_world.add_object(chest)
	return chest


func test_x_is_a_rebindable_action_that_switches_between_building_and_taking_down() -> void:
	assert_true(GameSettings.actions().has(&"take_down_mode"))
	assert_eq(
		(InputMap.action_get_events(&"take_down_mode")[0] as InputEventKey).physical_keycode, KEY_X
	)
	_hold(ItemTypes.HAMMER)
	assert_false(_builder.is_taking_down())
	_builder.toggle_taking_down()
	assert_true(_builder.is_taking_down())
	_builder.toggle_taking_down()
	assert_false(_builder.is_taking_down())


func test_taking_down_ends_with_the_hammer_and_with_dismissing() -> void:
	_hold(ItemTypes.HAMMER)
	_builder.toggle_taking_down()
	_hold(ItemTypes.HOE)
	_hold(ItemTypes.HAMMER)
	assert_false(_builder.is_taking_down())
	_builder.toggle_taking_down()
	_builder.dismiss()
	assert_false(_builder.is_taking_down())


func test_the_target_is_a_building_or_something_placed_and_nothing_else() -> void:
	var origin := _open_origin()
	var building := _world.place_building(BuildingTypes.SHACK, origin)
	assert_eq(_builder.take_down_target(origin).building, building)
	var chest := _place_a_chest()
	assert_eq(_builder.take_down_target(_tile).object, chest)
	assert_eq(_builder.take_down_target(_tile).display_name(), "Chest")
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, _tile + Vector2i(1, 0)))
	assert_null(_builder.take_down_target(_tile + Vector2i(1, 0)), "a tree is not taken down")
	assert_null(_builder.take_down_target(_tile + Vector2i(0, 5)))


func test_a_placed_thing_goes_to_the_inventory_with_what_it_held() -> void:
	_place_a_chest()
	var target := _builder.take_down_target(_tile)
	assert_eq(_builder.take_down_gives(target), {ItemTypes.CHEST: 1, ItemTypes.TURNIP: 4})
	_builder.take_down(target)
	assert_null(_world.object_at(_tile))
	assert_eq(_count(ItemTypes.CHEST), 1)
	assert_eq(_count(ItemTypes.TURNIP), 4)


func test_what_does_not_fit_lies_where_the_thing_stood() -> void:
	_place_a_chest()
	var inventory := _state.player.inventory
	for slot in inventory.slots.size():
		inventory.slots[slot] = {"item": ItemTypes.STONE, "count": 1}
	_builder.take_down(_builder.take_down_target(_tile))
	assert_eq(_world.ground_items.count_of(ItemTypes.CHEST), 1)
	assert_eq(_world.ground_items.count_of(ItemTypes.TURNIP), 4)


func test_a_building_gives_half_its_materials_at_the_door() -> void:
	var building := _world.place_building(BuildingTypes.SHACK, _open_origin())
	var target := _builder.take_down_target(building.origin)
	assert_eq(_builder.take_down_gives(target), {ItemTypes.LOGS: 10, ItemTypes.STONE: 2})
	_builder.take_down(target)
	assert_null(_world.building_at(building.origin))
	assert_eq(_world.ground_items.count_of(ItemTypes.LOGS), 10)
	assert_eq(_world.ground_items.count_of(ItemTypes.STONE), 2)


func test_a_building_with_something_placed_in_it_has_a_reason_not_to_be_taken_down() -> void:
	var building := _world.place_building(BuildingTypes.SHACK, _open_origin())
	assert_eq(_builder.why_not_take_down(_builder.take_down_target(building.origin)), "")
	_state.player.position = Vector2(building.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	building.interior.add_object(WorldObject.new(WorldObjectTypes.STOOL, Vector2i(2, 4)))
	_state.player.position = Vector2(building.interior.exit_tile) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_ne(_builder.why_not_take_down(_builder.take_down_target(building.origin)), "")


func test_taking_down_a_building_with_a_reason_to_stay_does_nothing() -> void:
	var building := _world.place_building(BuildingTypes.SHACK, _open_origin())
	_state.player.position = Vector2(building.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	building.interior.add_object(WorldObject.new(WorldObjectTypes.STOOL, Vector2i(2, 4)))
	_state.player.position = Vector2(building.interior.exit_tile) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_false(_builder.take_down(_builder.take_down_target(building.origin)))
	assert_eq(_world.buildings(), [building])
	assert_true(_world.ground_items.all().is_empty())
