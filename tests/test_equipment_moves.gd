extends GutTest
## Moves between the equipment and the inventory as one change: what listeners see, bad slots.

var _inventory: Inventory
var _equipment: Equipment


func before_each() -> void:
	_inventory = Inventory.new()
	_equipment = Equipment.new()


## How many garments exist (worn or carried) each time the inventory or the equipment says it
## changed while `move` runs.
func _garments_seen_during(move: Callable) -> Array:
	var seen := []
	var count_garments := func() -> void:
		var count := 0
		for item in [ItemTypes.WAISTCOAT, ItemTypes.SHIRT]:
			count += _inventory.count_of(item)
			count += 1 if _equipment.item_in(Equipment.BODY) == item else 0
		seen.append(count)
	_inventory.changed.connect(count_garments)
	_equipment.changed.connect(count_garments)
	move.call()
	# The listener holds the objects it listens to; let go so they are freed.
	_inventory.changed.disconnect(count_garments)
	_equipment.changed.disconnect(count_garments)
	return seen


func test_equipping_a_swap_never_shows_listeners_a_garment_twice_or_missing() -> void:
	_equipment.equip(Equipment.BODY, ItemTypes.WAISTCOAT)
	_inventory.slots[2] = {"item": ItemTypes.SHIRT, "count": 1}
	var seen := _garments_seen_during(
		func() -> void: _equipment.move_to_equipment(_inventory, 2, Equipment.BODY)
	)
	assert_eq(seen, [2, 2], "one notification from each side, both after the whole swap")


func test_taking_off_a_swap_never_shows_listeners_a_garment_twice_or_missing() -> void:
	_equipment.equip(Equipment.BODY, ItemTypes.WAISTCOAT)
	_inventory.slots[2] = {"item": ItemTypes.SHIRT, "count": 1}
	var seen := _garments_seen_during(
		func() -> void: _equipment.move_to_inventory(_inventory, Equipment.BODY, 2)
	)
	assert_eq(seen, [2, 2])


func test_moves_with_a_bad_inventory_slot_change_nothing() -> void:
	_equipment.equip(Equipment.BODY, ItemTypes.WAISTCOAT)
	watch_signals(_equipment)
	assert_false(_equipment.move_to_equipment(_inventory, -1, Equipment.BODY))
	assert_false(_equipment.move_to_equipment(_inventory, Inventory.SLOT_COUNT, Equipment.BODY))
	assert_false(_equipment.move_to_inventory(_inventory, Equipment.BODY, Inventory.SLOT_COUNT))
	assert_eq(_equipment.item_in(Equipment.BODY), ItemTypes.WAISTCOAT)
	assert_signal_not_emitted(_equipment, "changed")
