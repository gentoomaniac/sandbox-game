class_name Inventory
extends ItemSlots
## What the player carries: the hotbar (slots 0 to HOTBAR_SIZE - 1), one of which is selected:
## that item is held, and after it the backpack (BACKPACK_SIZE slots). The hotbar is extra room,
## it takes nothing from the backpack. Plain state; the hotbar and the inventory screen only
## show it and send it actions. `changed` also tells of the selection changing.

const HOTBAR_SIZE := 10
const BACKPACK_SIZE := 20
const SLOT_COUNT := HOTBAR_SIZE + BACKPACK_SIZE

## What a new game starts with: item and count, in slot order.
const STARTING_ITEMS := [
	[ItemTypes.HOE, 1],
	[ItemTypes.AXE, 1],
	[ItemTypes.PICKAXE, 1],
	[ItemTypes.WATERING_CAN, 1],
	[ItemTypes.TURNIP_SEEDS, 15],
	[ItemTypes.SCYTHE, 1],
	[ItemTypes.SHOVEL, 1],
	[ItemTypes.HAMMER, 1],
]
## What a new game starts with in the backpack (from the slot after the hotbar), so the hotbar
## keeps room for what the player picks up.
const STARTING_BACKPACK := [
	[ItemTypes.STRAW_HAT, 1],
	[ItemTypes.KNITTED_CAP, 1],
	[ItemTypes.SHIRT, 1],
]

## The hotbar slot the player holds.
var selected_slot := 0


func _init() -> void:
	super(SLOT_COUNT)


static func with_starting_items() -> Inventory:
	var inventory := Inventory.new()
	for slot in STARTING_ITEMS.size():
		inventory.slots[slot] = {"item": STARTING_ITEMS[slot][0], "count": STARTING_ITEMS[slot][1]}
	for index in STARTING_BACKPACK.size():
		inventory.slots[HOTBAR_SIZE + index] = {
			"item": STARTING_BACKPACK[index][0], "count": STARTING_BACKPACK[index][1]
		}
	return inventory


## The item in the selected slot, or ItemTypes.NONE for an empty hand.
func held_item() -> StringName:
	return item_in(selected_slot)


func select(hotbar_slot: int) -> void:
	assert(hotbar_slot >= 0 and hotbar_slot < HOTBAR_SIZE, "Not a hotbar slot: %d" % hotbar_slot)
	selected_slot = hotbar_slot
	changed.emit()


func total_weight() -> float:
	var total := 0.0
	for stack in slots:
		if not stack.is_empty():
			total += stack["count"] * ItemTypes.TYPES[stack["item"]]["weight"]
	return total


## A copy to try things on: changing it leaves this inventory alone.
func duplicate() -> Inventory:
	var copy := Inventory.new()
	copy.slots = slots.duplicate(true)
	copy.selected_slot = selected_slot
	return copy


func to_dict() -> Dictionary:
	return {"slots": slots_to_data(), "selected_slot": selected_slot}


static func from_dict(data: Dictionary) -> Inventory:
	var inventory := Inventory.new()
	inventory.load_slots(data["slots"])
	inventory.selected_slot = int(data["selected_slot"])
	return inventory


## Free slots are taken hotbar first, and the selected slot only when nothing else is free (so
## an empty hand stays empty after a harvest).
func _free_slot_order() -> Array:
	var order := super()
	order.erase(selected_slot)
	order.append(selected_slot)
	return order


## The free slots for something coming out of a chest: the backpack before the hotbar, so the
## hotbar isn't flooded.
func backpack_first_order() -> Array:
	var order := _free_slot_order()
	var backpack := order.filter(func(slot: int) -> bool: return slot >= HOTBAR_SIZE)
	var hotbar := order.filter(func(slot: int) -> bool: return slot < HOTBAR_SIZE)
	return backpack + hotbar
