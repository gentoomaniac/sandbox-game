extends GutTest
## Equipment: wearing, taking off and swapping with the inventory, only into slots that fit;
## the right-click moves.

var _inventory: Inventory
var _equipment: Equipment


func before_each() -> void:
	_inventory = Inventory.new()
	_equipment = Equipment.new()


func test_equipping_puts_the_item_in_the_slot() -> void:
	_equipment.equip(Equipment.HEAD, ItemTypes.STRAW_HAT)
	assert_eq(_equipment.item_in(Equipment.HEAD), ItemTypes.STRAW_HAT)
	assert_eq(_equipment.item_in(Equipment.BODY), ItemTypes.NONE)


func test_unequipping_returns_the_item_and_empties_the_slot() -> void:
	_equipment.equip(Equipment.HEAD, ItemTypes.STRAW_HAT)
	assert_eq(_equipment.unequip(Equipment.HEAD), ItemTypes.STRAW_HAT)
	assert_eq(_equipment.item_in(Equipment.HEAD), ItemTypes.NONE)
	assert_eq(_equipment.unequip(Equipment.HEAD), ItemTypes.NONE)


func test_an_item_fits_only_its_own_slot() -> void:
	assert_true(Equipment.fits(Equipment.HEAD, ItemTypes.STRAW_HAT))
	assert_false(Equipment.fits(Equipment.BODY, ItemTypes.STRAW_HAT))
	assert_false(Equipment.fits(Equipment.MAIN_HAND, ItemTypes.HOE))
	assert_false(Equipment.fits(Equipment.HEAD, ItemTypes.NONE))


func test_every_wearable_has_a_slot_a_layer_and_a_stack_of_one() -> void:
	for item: StringName in ItemTypes.TYPES:
		if Equipment.slot_of(item) != ItemTypes.NONE:
			assert_true(Equipment.slot_of(item) in Equipment.SLOTS, str(item))
			assert_eq(ItemTypes.TYPES[item]["stack_limit"], 1, str(item))
			assert_true(ItemTypes.TYPES[item].has("layer_variant"), str(item))


func test_moving_an_item_into_a_free_slot() -> void:
	_inventory.slots[3] = {"item": ItemTypes.STRAW_HAT, "count": 1}
	assert_true(_equipment.move_to_equipment(_inventory, 3, Equipment.HEAD))
	assert_eq(_equipment.item_in(Equipment.HEAD), ItemTypes.STRAW_HAT)
	assert_true(_inventory.slots[3].is_empty())


func test_moving_an_item_into_the_wrong_slot_changes_nothing() -> void:
	_inventory.slots[3] = {"item": ItemTypes.STRAW_HAT, "count": 1}
	assert_false(_equipment.move_to_equipment(_inventory, 3, Equipment.BODY))
	assert_eq(_inventory.item_in(3), ItemTypes.STRAW_HAT)
	assert_eq(_equipment.item_in(Equipment.BODY), ItemTypes.NONE)


func test_moving_something_that_is_not_wearable_is_refused() -> void:
	_inventory.slots[0] = {"item": ItemTypes.HOE, "count": 1}
	assert_false(_equipment.move_to_equipment(_inventory, 0, Equipment.MAIN_HAND))
	assert_false(_equipment.move_to_equipment(_inventory, 1, Equipment.HEAD))


func test_moving_onto_a_worn_item_swaps_them() -> void:
	_equipment.equip(Equipment.BODY, ItemTypes.WAISTCOAT)
	_inventory.slots[2] = {"item": ItemTypes.SHIRT, "count": 1}
	assert_true(_equipment.move_to_equipment(_inventory, 2, Equipment.BODY))
	assert_eq(_equipment.item_in(Equipment.BODY), ItemTypes.SHIRT)
	assert_eq(_inventory.item_in(2), ItemTypes.WAISTCOAT)


func test_moving_a_worn_item_to_a_free_inventory_slot() -> void:
	_equipment.equip(Equipment.LEGS, ItemTypes.BREECHES)
	assert_true(_equipment.move_to_inventory(_inventory, Equipment.LEGS, 7))
	assert_eq(_inventory.item_in(7), ItemTypes.BREECHES)
	assert_eq(_equipment.item_in(Equipment.LEGS), ItemTypes.NONE)


func test_moving_a_worn_item_onto_an_item_that_fits_swaps_them() -> void:
	_equipment.equip(Equipment.BODY, ItemTypes.WAISTCOAT)
	_inventory.slots[4] = {"item": ItemTypes.SHIRT, "count": 1}
	assert_true(_equipment.move_to_inventory(_inventory, Equipment.BODY, 4))
	assert_eq(_equipment.item_in(Equipment.BODY), ItemTypes.SHIRT)
	assert_eq(_inventory.item_in(4), ItemTypes.WAISTCOAT)


func test_moving_a_worn_item_onto_an_item_that_does_not_fit_is_refused() -> void:
	_equipment.equip(Equipment.BODY, ItemTypes.WAISTCOAT)
	_inventory.slots[4] = {"item": ItemTypes.STRAW_HAT, "count": 1}
	assert_false(_equipment.move_to_inventory(_inventory, Equipment.BODY, 4))
	assert_eq(_equipment.item_in(Equipment.BODY), ItemTypes.WAISTCOAT)
	assert_eq(_inventory.item_in(4), ItemTypes.STRAW_HAT)


func test_moving_from_an_empty_equipment_slot_is_refused() -> void:
	assert_false(_equipment.move_to_inventory(_inventory, Equipment.HEAD, 0))


func test_quick_equip_wears_the_item_in_its_slot() -> void:
	_inventory.slots[5] = {"item": ItemTypes.STRAW_HAT, "count": 1}
	assert_true(_equipment.quick_equip(_inventory, 5))
	assert_eq(_equipment.item_in(Equipment.HEAD), ItemTypes.STRAW_HAT)
	assert_true(_inventory.slots[5].is_empty())


func test_quick_equip_swaps_the_worn_item_into_the_same_slot() -> void:
	_equipment.equip(Equipment.BODY, ItemTypes.WAISTCOAT)
	_inventory.slots[5] = {"item": ItemTypes.SHIRT, "count": 1}
	assert_true(_equipment.quick_equip(_inventory, 5))
	assert_eq(_inventory.item_in(5), ItemTypes.WAISTCOAT)


func test_quick_equip_refuses_what_is_not_wearable_or_empty() -> void:
	_inventory.slots[0] = {"item": ItemTypes.HOE, "count": 1}
	assert_false(_equipment.quick_equip(_inventory, 0))
	assert_false(_equipment.quick_equip(_inventory, 1))


func test_quick_unequip_goes_to_the_first_free_slot() -> void:
	_equipment.equip(Equipment.HEAD, ItemTypes.STRAW_HAT)
	_inventory.slots[0] = {"item": ItemTypes.HOE, "count": 1}
	assert_true(_equipment.quick_unequip(_inventory, Equipment.HEAD))
	assert_eq(_inventory.item_in(1), ItemTypes.STRAW_HAT)


func test_quick_unequip_with_a_full_inventory_is_refused() -> void:
	_equipment.equip(Equipment.HEAD, ItemTypes.STRAW_HAT)
	for slot in Inventory.SLOT_COUNT:
		_inventory.slots[slot] = {"item": ItemTypes.LOGS, "count": 1}
	assert_false(_equipment.quick_unequip(_inventory, Equipment.HEAD))
	assert_eq(_equipment.item_in(Equipment.HEAD), ItemTypes.STRAW_HAT)


func test_moves_tell_the_inventory_and_the_equipment_changed() -> void:
	_inventory.slots[0] = {"item": ItemTypes.STRAW_HAT, "count": 1}
	watch_signals(_inventory)
	watch_signals(_equipment)
	_equipment.quick_equip(_inventory, 0)
	assert_signal_emitted(_inventory, "changed")
	assert_signal_emitted(_equipment, "changed")


func test_destroying_a_worn_item_empties_its_slot_and_leaves_the_rest() -> void:
	_equipment.equip(Equipment.HEAD, ItemTypes.STRAW_HAT)
	_equipment.equip(Equipment.BODY, ItemTypes.SHIRT)
	watch_signals(_equipment)
	_equipment.destroy(Equipment.HEAD)
	assert_eq(_equipment.item_in(Equipment.HEAD), ItemTypes.NONE)
	assert_eq(_equipment.item_in(Equipment.BODY), ItemTypes.SHIRT)
	assert_signal_emitted(_equipment, "changed")
