extends ResourceCase
## Where a recipe is made: at a station of its kind on the player's map within their reach. A
## refusal takes nothing and teaches nothing. A process station's run is refused out of reach too.

var _crafting: Crafting
var _workbench: WorldObject
var _campfire: WorldObject


func before_each() -> void:
	super.before_each()
	_crafting = Crafting.new(_state)
	_workbench = _place(WorldObjectTypes.WORKBENCH)
	_campfire = _place_beside(WorldObjectTypes.FIREPLACE)
	_state.player.inventory.add(ItemTypes.LOGS, 2)


func _assert_refused_without_side_effects(
	station: WorldObject, result: Crafting.Result, message: String
) -> void:
	var before := _state.player.inventory.totals()
	assert_eq(_crafting.craft(&"planks", station), result, message)
	assert_eq(_state.player.inventory.totals(), before, message)
	assert_eq(_state.player.skills.points(&"woodworking"), 0.0, message)


func test_planks_are_refused_at_a_campfire_without_taking_anything() -> void:
	_assert_refused_without_side_effects(
		_campfire, Crafting.Result.WRONG_STATION, "a campfire is no workbench"
	)


func test_planks_are_refused_without_a_station_or_at_one_that_is_not_on_the_map() -> void:
	_assert_refused_without_side_effects(null, Crafting.Result.NO_STATION, "no station")
	var unattached := WorldObject.new(WorldObjectTypes.WORKBENCH, Vector2i(999, 999))
	_assert_refused_without_side_effects(
		unattached, Crafting.Result.NO_STATION, "a workbench that stands nowhere"
	)


func test_planks_are_refused_out_of_reach_and_made_again_in_reach() -> void:
	_state.player.position += Vector2(5.0, 0.0)
	_assert_refused_without_side_effects(
		_workbench, Crafting.Result.NO_STATION, "a workbench five tiles away"
	)
	_state.player.position -= Vector2(5.0, 0.0)
	assert_eq(_crafting.craft(&"planks", _workbench), Crafting.Result.CRAFTED)


func test_the_menu_says_why_a_craft_is_refused_when_the_player_has_walked_off() -> void:
	var screen := CraftingScreen.new()
	add_child_autofree(screen)
	screen.show_crafting(_crafting, _state.player.inventory)
	screen.open_station(_workbench)
	_state.player.position += Vector2(5.0, 0.0)
	var before := _state.player.inventory.totals()
	screen.find_children("*", "RecipeRow", true, false)[0].pressed.emit()
	var notes := screen.find_children("*", "Label", true, false).map(
		func(label: Label) -> String: return label.text
	)
	assert_has(notes, CraftingScreen.NO_STATION_NOTE)
	assert_eq(_state.player.inventory.totals(), before)


func test_planks_are_refused_at_a_workbench_of_the_other_map() -> void:
	var house: Building = null
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := _state.player.tile() + Vector2i(x, y)
			if house == null and _world.placement_blockers(BuildingTypes.KATE, origin).is_empty():
				house = _world.place_building(BuildingTypes.KATE, origin)
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_true(_state.is_inside())
	_assert_refused_without_side_effects(
		_workbench, Crafting.Result.NO_STATION, "a workbench outside"
	)


func test_a_firing_is_refused_out_of_reach_and_practises_nothing() -> void:
	_world.remove_object(_tile + Vector2i.RIGHT)
	var kiln := ProcessStation.new(_state, _crafting, _place_beside(WorldObjectTypes.KILN))
	_state.player.inventory.add(ItemTypes.RAW_BRICK, 6)
	kiln.fill(&"bricks", 1)
	_state.player.position += Vector2(5.0, 0.0)
	assert_false(kiln.start(), "a kiln five tiles away")
	assert_false(kiln.is_running())
	assert_eq(_state.player.skills.points(&"masonry"), 0.0)
	_state.player.position -= Vector2(5.0, 0.0)
	assert_true(kiln.start())


func test_a_result_that_partly_fits_goes_in_and_the_rest_is_dropped() -> void:
	for slot in Inventory.SLOT_COUNT:
		_state.player.inventory.slots[slot] = {"item": ItemTypes.RUSTY_IRON_HOE, "count": 1}
	_state.player.inventory.slots[3] = {"item": ItemTypes.LOGS, "count": 2}
	_state.player.inventory.slots[4] = {"item": ItemTypes.PLANKS, "count": 98}
	assert_eq(_crafting.craft(&"planks", _workbench), Crafting.Result.DROPPED)
	assert_eq(_state.player.inventory.count_of(ItemTypes.PLANKS), 99)
	assert_eq(_world.ground_items.count_of(ItemTypes.PLANKS), 1)
