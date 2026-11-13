class_name HotbarHold
extends RefCounted
## Puts an item in the player's hand for a test. The starting hotbar has no free slot, so an
## empty hand, or an item that came in by harvest or pickup (into the backpack), takes the held
## slot by swapping with it (see Inventory `hold`).


## Holds `item` (ItemTypes.NONE for an empty hand), fetching it into the held slot if it is not
## on the hotbar. An item the inventory doesn't have yet is added first.
static func hold(inventory: Inventory, item: StringName) -> void:
	inventory.hold(item)
