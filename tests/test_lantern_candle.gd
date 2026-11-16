extends GutTest
## The lantern holds a candle that keeps its own burn (task 231): fitted, taken out, burnt down
## while the lantern shines in the hand, never over a night's sleep.

const LIFE := 24 * 60

var _state: GameState
var _inventory: Inventory


func before_each() -> void:
	_state = GameFactory.new_game(7)
	_state.player.inventory = Inventory.new()
	_inventory = _state.player.inventory
	_inventory.slots[7] = {"item": ItemTypes.LANTERN, "count": 1}
	_inventory.select(7)


func _put_candle(slot: int, burnt_minutes := 0) -> void:
	_inventory.slots[slot] = {"item": ItemTypes.CANDLE, "count": 1}
	if burnt_minutes > 0:
		_inventory.set_state(slot, {"burnt_minutes": burnt_minutes})


func _candle_in_lantern() -> Variant:
	var state: Dictionary = _inventory.slots[7].get("state", {})
	return state.get("candle")


func test_the_lantern_is_made_at_the_workbench_without_a_candle() -> void:
	var rules := RecipeRules.default_rules()
	assert_eq(rules.result(&"lantern"), ItemTypes.LANTERN)
	assert_eq(rules.station_of(&"lantern"), &"workbench")
	assert_eq(rules.level(&"lantern"), 0.0, "a new game's player can make it")
	assert_eq(rules.materials(&"lantern"), {ItemTypes.PLANKS: 2, ItemTypes.FIBRE: 2})
	var workbench := WorldObject.new(
		WorldObjectTypes.WORKBENCH, _state.player.tile() + Vector2i.RIGHT
	)
	_state.world.add_object(workbench)
	_inventory.add(ItemTypes.PLANKS, 2)
	_inventory.add(ItemTypes.FIBRE, 2)

	assert_eq(Crafting.new(_state).craft(&"lantern", workbench), Crafting.Result.CRAFTED)

	assert_eq(_inventory.count_of(ItemTypes.LANTERN), 2, "one was already in the slot")


func test_using_a_lantern_without_a_candle_fits_the_freshest_and_stays_dark() -> void:
	assert_false(_state.switch_held_lantern(), "no candle to fit")
	_put_candle(8, 600)
	_put_candle(9)
	_put_candle(10, 1200)

	assert_true(_state.switch_held_lantern())

	assert_eq(_candle_in_lantern(), {}, "the fresh one")
	assert_eq(_inventory.item_in(9), ItemTypes.NONE)
	assert_eq(_inventory.item_in(8), ItemTypes.CANDLE)
	assert_eq(_inventory.item_in(10), ItemTypes.CANDLE)
	assert_false(_state.player.is_lantern_lit)
	assert_true(_state.switch_held_lantern())
	assert_true(_state.player.is_lantern_shining())


func test_a_lit_lantern_burns_its_candle_down_and_the_candle_keeps_the_burn() -> void:
	_put_candle(8)
	_state.switch_held_lantern()
	_state.switch_held_lantern()

	PlayerRest.pass_awake_time(_state, 6 * 60)

	assert_eq(_candle_in_lantern(), {"burnt_minutes": 360})
	assert_true(_state.player.is_lantern_shining())


func test_a_candle_taken_out_comes_back_as_it_is_and_stacks_only_if_fresh() -> void:
	_inventory.slots[7]["state"] = {"candle": {"burnt_minutes": 100}}
	_state.player.is_lantern_lit = true
	_inventory.slots[8] = {"item": ItemTypes.CANDLE, "count": 3}

	assert_true(_state.player.take_candle_out(7))

	assert_false(_inventory.slots[7].has("state"), "empty")
	assert_false(_state.player.is_lantern_lit, "and out")
	assert_eq(
		_inventory.slots[8], {"item": ItemTypes.CANDLE, "count": 3}, "not onto the plain stack"
	)
	assert_eq(_inventory.count_of(ItemTypes.CANDLE), 4)
	var burnt := _inventory.slots.filter(func(stack: Dictionary) -> bool: return stack.has("state"))
	assert_eq(burnt[0], {"item": ItemTypes.CANDLE, "count": 1, "state": {"burnt_minutes": 100}})

	_inventory.slots[7]["state"] = {"candle": {}}
	assert_true(_state.player.take_candle_out(7))
	assert_eq(_inventory.count_of(ItemTypes.CANDLE), 5)
	var plain := _inventory.slots.filter(
		func(stack: Dictionary) -> bool:
			return stack.get("item") == ItemTypes.CANDLE and not stack.has("state")
	)
	assert_eq(plain.size(), 2, "the fresh one is a plain candle in a stack of its own")


func test_a_candle_that_has_no_room_stays_in_the_lantern() -> void:
	for slot in Inventory.SLOT_COUNT:
		if slot != 7:
			_inventory.slots[slot] = {"item": ItemTypes.STONE, "count": 1}
	_inventory.slots[7]["state"] = {"candle": {"burnt_minutes": 100}}

	assert_false(_state.player.take_candle_out(7))

	assert_eq(_candle_in_lantern(), {"burnt_minutes": 100})


func test_a_candle_that_burns_out_is_gone_and_the_lantern_goes_out() -> void:
	_inventory.slots[7]["state"] = {"candle": {"burnt_minutes": LIFE - 10}}
	_state.player.is_lantern_lit = true

	PlayerRest.pass_awake_time(_state, 10)

	assert_false(_inventory.slots[7].has("state"), "no candle, none given back")
	assert_eq(_inventory.count_of(ItemTypes.CANDLE), 0)
	assert_false(_state.player.is_lantern_lit)
	assert_false(_state.player.is_lantern_shining())


func test_an_unlit_or_unheld_lantern_burns_nothing() -> void:
	_inventory.slots[7]["state"] = {"candle": {}}
	PlayerRest.pass_awake_time(_state, 120)
	assert_eq(_candle_in_lantern(), {}, "not lit")
	_state.switch_held_lantern()
	_inventory.select(0)
	PlayerRest.pass_awake_time(_state, 120)
	assert_eq(_candle_in_lantern(), {}, "lit but in the bag")


func test_going_to_bed_puts_the_lantern_out_and_the_candle_burns_nothing_overnight() -> void:
	_inventory.slots[7]["state"] = {"candle": {}}
	_state.switch_held_lantern()
	assert_true(_state.player.is_lantern_lit)
	var bed := WorldObject.new(WorldObjectTypes.SLEEPING_BAG, _state.player.tile())
	for tile in bed.tiles():
		_state.world.remove_object(tile)
	_state.world.add_object(bed)
	_state.clock.set_time(21, 0)

	PlayerRest.sleep_in(_state, bed)

	assert_false(_state.player.is_lantern_lit)
	assert_eq(_candle_in_lantern(), {})


func test_passing_out_puts_the_lantern_out_too() -> void:
	_inventory.slots[7]["state"] = {"candle": {}}
	_state.switch_held_lantern()

	PlayerRest.pass_out(_state)

	assert_false(_state.player.is_lantern_lit)
	assert_eq(_candle_in_lantern(), {})


func test_fitting_a_candle_puts_a_lit_flag_out_so_the_lantern_stays_dark() -> void:
	_put_candle(8)
	_state.player.is_lantern_lit = true

	assert_true(_state.switch_held_lantern())

	assert_false(_state.player.is_lantern_lit)
	assert_false(_state.player.is_lantern_shining())


func test_a_lantern_and_a_burnt_candle_are_dropped_with_their_state_and_picked_up_with_it() -> void:
	var states := {
		7: {"candle": {}},
		8: {"candle": {"burnt_minutes": 500}},
		9: {},
	}
	_put_candle(10, 50)
	var wanted := {}
	for slot: int in states:
		_inventory.slots[slot] = {"item": ItemTypes.LANTERN, "count": 1}
		_inventory.set_state(slot, states[slot])
		wanted[slot] = _inventory.slots[slot].duplicate(true)
	wanted[10] = _inventory.slots[10].duplicate(true)
	for slot: int in wanted:
		assert_true(GroundPickup.drop(_state, slot), "slot %d" % slot)
		assert_true(_inventory.slots[slot].is_empty())

	var piles := _state.world.ground_items.all()
	assert_eq(piles.size(), 4, "each a pile of its own")
	for pile in piles:
		assert_eq(pile.count, 1)
		pile.is_dropped_by_player = false
		pile.settle_seconds = 0.0
		pile.position = _state.player.position
	GroundPickup.collect(_state, 1.0 / 60.0)
	for _frame in 120:
		GroundPickup.collect(_state, 1.0 / 60.0)

	assert_eq(_state.world.ground_items.all().size(), 0)
	var back := _inventory.slots.filter(
		func(stack: Dictionary) -> bool: return not stack.is_empty()
	)
	var lanterns := back.filter(
		func(stack: Dictionary) -> bool: return stack["item"] == ItemTypes.LANTERN
	)
	assert_eq(lanterns.size(), 3)
	for stack: Dictionary in wanted.values():
		assert_true(back.has(stack), "%s is back as it was" % stack)


func test_the_tooltip_and_the_icon_tell_how_much_candle_is_left() -> void:
	var lantern := {"item": ItemTypes.LANTERN, "count": 1}
	assert_string_contains(ItemTooltip.text_for(ItemTypes.LANTERN, 1, {}), "No candle in it")
	assert_eq(LanternCandle.icon_item(lantern), &"lantern_empty")
	var states := {0: &"lantern", LIFE / 2: &"lantern_used", LIFE - 60: &"lantern_stub"}
	for burnt: int in states:
		lantern["state"] = {"candle": {"burnt_minutes": burnt} if burnt > 0 else {}}
		assert_eq(LanternCandle.icon_item(lantern), states[burnt], "burnt %d" % burnt)
	lantern["state"] = {"candle": {"burnt_minutes": LIFE / 4}}
	assert_string_contains(
		ItemTooltip.text_for(ItemTypes.LANTERN, 1, lantern["state"]), "Candle: 75% left"
	)
	assert_string_contains(
		ItemTooltip.text_for(ItemTypes.CANDLE, 1, {"burnt_minutes": LIFE / 2}),
		"Burnt down: 50% left"
	)


func test_the_use_of_the_held_lantern_is_asked_before_it_is_done() -> void:
	assert_eq(_state.held_lantern_use(), GameState.LanternUse.NONE, "no candle to fit")
	_put_candle(8)
	assert_eq(_state.held_lantern_use(), GameState.LanternUse.FIT_CANDLE)
	_state.switch_held_lantern()
	assert_eq(_state.held_lantern_use(), GameState.LanternUse.LIGHT, "fitted, and dark")
	_state.switch_held_lantern()
	assert_eq(_state.held_lantern_use(), GameState.LanternUse.PUT_OUT, "lit")
	_inventory.select(0)
	assert_eq(_state.held_lantern_use(), GameState.LanternUse.NONE, "not the lantern in hand")
