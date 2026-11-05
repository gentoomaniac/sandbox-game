extends ResourceCase
## The hammer: holding it is build mode, Q and E pick the building, placing takes the costs.

var _builder: Builder


func before_each() -> void:
	super.before_each()
	_builder = Builder.new(_state)


## A top left tile near the camp where the chosen building can be placed.
func _open_origin() -> Vector2i:
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := _state.player.tile() + Vector2i(x, y)
			if _world.placement_blockers(_builder.choice, origin).is_empty():
				return origin
	fail_test("no room for a %s near the camp" % _builder.choice)
	return Vector2i.ZERO


## Puts exactly what the chosen building costs, plus `extra` of each, in the inventory.
func _stock_up(extra := 0) -> void:
	for item: StringName in _builder.costs():
		_state.player.inventory.add(item, _builder.costs()[item] + extra)


func test_the_player_starts_with_a_hammer_and_is_not_building() -> void:
	assert_eq(_count(ItemTypes.HAMMER), 1)
	assert_false(_builder.is_building())


func test_holding_the_hammer_is_build_mode() -> void:
	_hold(ItemTypes.HAMMER)
	assert_true(_builder.is_building())
	_hold(ItemTypes.HOE)
	assert_false(_builder.is_building())


func test_select_hammer_holds_it() -> void:
	_hold(ItemTypes.HOE)
	assert_true(_builder.select_hammer())
	assert_eq(_state.player.inventory.held_item(), ItemTypes.HAMMER)
	assert_true(_builder.is_building())


func test_select_hammer_does_nothing_without_a_hammer() -> void:
	_state.player.inventory.remove(ItemTypes.HAMMER, 1)
	_hold(ItemTypes.HOE)
	assert_false(_builder.select_hammer())
	assert_eq(_state.player.inventory.held_item(), ItemTypes.HOE)


func test_dismissing_lasts_until_something_else_is_held_or_the_hammer_is_selected() -> void:
	_builder.select_hammer()
	_builder.dismiss()
	assert_false(_builder.is_building())
	assert_eq(_state.player.inventory.held_item(), ItemTypes.HAMMER)
	_builder.select_hammer()
	assert_true(_builder.is_building())
	_builder.dismiss()
	_hold(ItemTypes.HOE)
	_hold(ItemTypes.HAMMER)
	assert_true(_builder.is_building())


func test_picking_goes_through_the_buildings_in_order_and_wraps() -> void:
	var ids := BuildingTypes.ids()
	assert_eq(_builder.choice, ids[0])
	_builder.pick(1)
	assert_eq(_builder.choice, ids[1])
	_builder.pick(-1)
	_builder.pick(-1)
	assert_eq(_builder.choice, ids[-1], "before the first is the last")
	_builder.pick(1)
	assert_eq(_builder.choice, ids[0], "after the last is the first")


func test_the_costs_are_the_buildings_from_the_file() -> void:
	_builder.choice = BuildingTypes.KATE
	assert_eq(
		_builder.costs(),
		{ItemTypes.LOGS: 30, ItemTypes.STONE: 15, ItemTypes.CLAY: 15, ItemTypes.REEDS: 25}
	)
	_builder.choice = BuildingTypes.SHACK
	assert_eq(_builder.costs(), {ItemTypes.LOGS: 20, ItemTypes.STONE: 5, ItemTypes.REEDS: 5})


func test_placing_takes_the_materials() -> void:
	_builder.choice = BuildingTypes.KATE
	_stock_up(3)
	var building := _builder.place(_open_origin())
	assert_not_null(building)
	assert_eq(building.type, BuildingTypes.KATE)
	for item: StringName in _builder.costs():
		assert_eq(_count(item), 3, str(item))


func test_every_building_can_be_placed_when_its_costs_are_carried() -> void:
	for id in BuildingTypes.ids():
		_builder.choice = id
		_stock_up()
		var origin := _open_origin()
		var building := _builder.place(origin)
		assert_not_null(building, str(id))
		assert_eq(building.origin, origin)
		for item: StringName in _builder.costs():
			assert_eq(_count(item), 0, "%s %s" % [id, item])


func test_a_spot_is_refused_while_something_is_missing() -> void:
	_builder.choice = BuildingTypes.LONGHOUSE
	_stock_up()
	_state.player.inventory.remove(ItemTypes.CLAY, 1)
	assert_eq(_builder.shortfalls(), {ItemTypes.CLAY: 1})
	assert_null(_builder.place(_open_origin()))
	assert_true(_world.buildings().is_empty())
	assert_eq(_count(ItemTypes.LOGS), _builder.costs()[ItemTypes.LOGS], "nothing was taken")


func test_a_refused_spot_takes_nothing_either() -> void:
	_builder.choice = BuildingTypes.SHACK
	_stock_up()
	var origin := _open_origin()
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, origin))
	assert_null(_builder.place(origin))
	assert_eq(_count(ItemTypes.LOGS), _builder.costs()[ItemTypes.LOGS])


func test_shortfalls_say_how_many_are_missing() -> void:
	_builder.choice = BuildingTypes.SHACK
	_state.player.inventory.add(ItemTypes.LOGS, 8)
	assert_eq(_builder.shortfalls(), {ItemTypes.LOGS: 12, ItemTypes.STONE: 5, ItemTypes.REEDS: 5})


func test_the_nocost_cheat_waives_the_costs_and_takes_nothing() -> void:
	Console.new(_state).run("nocost")
	_builder.choice = BuildingTypes.KATE
	assert_true(_builder.shortfalls().is_empty())
	assert_not_null(_builder.place(_open_origin()))
	assert_eq(_count(ItemTypes.LOGS), 0)


func test_the_other_cheats_do_not_waive_the_costs() -> void:
	var console := Console.new(_state)
	console.run("god")
	console.run("nodrain")
	console.run("noweight")
	_builder.choice = BuildingTypes.SHACK
	assert_false(_builder.shortfalls().is_empty())
	assert_null(_builder.place(_open_origin()))


func test_q_and_e_are_rebindable_actions_and_b_selects_the_hammer() -> void:
	var actions := GameSettings.actions()
	for action in [&"build_previous", &"build_next", &"select_hammer"]:
		assert_true(actions.has(action), str(action))
		assert_ne(GameSettings.action_label(action), "", str(action))
	assert_eq(
		(InputMap.action_get_events(&"build_previous")[0] as InputEventKey).physical_keycode, KEY_Q
	)
	assert_eq(
		(InputMap.action_get_events(&"build_next")[0] as InputEventKey).physical_keycode, KEY_E
	)
	assert_eq(
		(InputMap.action_get_events(&"select_hammer")[0] as InputEventKey).physical_keycode, KEY_B
	)
