extends GutTest
## Using the held item takes it from the selected slot, also when more stacks of it are carried.

var _state: GameState
var _inventory: Inventory


func before_each() -> void:
	_state = GameState.new_game(7)
	_inventory = _state.player.inventory
	_inventory.slots[0] = {"item": ItemTypes.BERRIES, "count": 2}
	_inventory.slots[Inventory.SLOT_COUNT - 1] = {"item": ItemTypes.BERRIES, "count": 5}
	_inventory.select(0)


func test_eating_takes_a_berry_from_the_held_stack_not_the_last_one() -> void:
	_state.player.energy = 0.0
	assert_true(_state.eat_held())
	assert_eq(_inventory.slots[0]["count"], 1)
	assert_eq(_inventory.slots[Inventory.SLOT_COUNT - 1]["count"], 5)


func test_eating_the_last_berry_of_the_held_stack_empties_the_hand() -> void:
	_state.player.energy = 0.0
	_state.eat_held()
	_state.eat_held()
	assert_eq(_inventory.held_item(), ItemTypes.NONE)
	assert_eq(_inventory.count_of(ItemTypes.BERRIES), 5)


func test_consuming_an_empty_hand_does_nothing() -> void:
	_inventory.select(1)
	_inventory.slots[1] = {}
	watch_signals(_inventory)
	assert_false(_inventory.consume_held())
	assert_signal_not_emitted(_inventory, "changed")
