class_name HotbarHold
extends RefCounted
## Puts an item in the player's hand for a test. The starting hotbar has no free slot, so an
## empty hand, or an item that came in by harvest or pickup (into the backpack), takes the held
## slot by swapping with it.


## Holds `item` (ItemTypes.NONE for an empty hand), fetching it into the held slot if it is not
## on the hotbar. An item the inventory doesn't have yet is added first.
static func hold(inventory: Inventory, item: StringName) -> void:
	for slot in Inventory.HOTBAR_SIZE:
		if inventory.item_in(slot) == item:
			inventory.select(slot)
			return
	var has_item := func(stack: Dictionary) -> bool:
		return stack.get("item", ItemTypes.NONE) == item
	var source := inventory.slots.find_custom(has_item)
	if source == -1:
		inventory.add(item, 1)
		source = inventory.slots.find_custom(has_item)
	var held := inventory.selected_slot
	var displaced := inventory.slots[held]
	inventory.slots[held] = inventory.slots[source]
	inventory.slots[source] = displaced
