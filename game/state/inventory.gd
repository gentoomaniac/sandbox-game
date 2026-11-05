class_name Inventory
extends RefCounted
## What the player carries: SLOT_COUNT slots, the first HOTBAR_SIZE of them the hotbar, one of
## which is selected: that item is held. Plain state; the hotbar and the inventory screen only
## show it and send it actions.
##
## A slot is empty (`{}`) or a stack `{item: StringName, count: int}`: an item id from
## ItemTypes and at most its stack limit.

## Whenever a slot or the selection changes.
signal changed

const SLOT_COUNT := 20
const HOTBAR_SIZE := 10

## What a new game starts with: item and count, in slot order.
const STARTING_ITEMS := [
	[ItemTypes.HOE, 1],
	[ItemTypes.AXE, 1],
	[ItemTypes.PICKAXE, 1],
	[ItemTypes.WATERING_CAN, 1],
	[ItemTypes.TURNIP_SEEDS, 15],
]

var slots: Array[Dictionary] = []
## The hotbar slot the player holds.
var selected_slot := 0


func _init() -> void:
	for slot in SLOT_COUNT:
		slots.append({})


static func with_starting_items() -> Inventory:
	var inventory := Inventory.new()
	for item_and_count in STARTING_ITEMS:
		inventory.add(item_and_count[0], item_and_count[1])
	return inventory


## The item in the selected slot, or ItemTypes.NONE for an empty hand.
func held_item() -> StringName:
	return item_in(selected_slot)


func item_in(slot: int) -> StringName:
	return slots[slot].get("item", ItemTypes.NONE)


func select(hotbar_slot: int) -> void:
	assert(hotbar_slot >= 0 and hotbar_slot < HOTBAR_SIZE, "Not a hotbar slot: %d" % hotbar_slot)
	selected_slot = hotbar_slot
	changed.emit()


## Puts `count` of `item` in: first onto stacks of it that have room, then into free slots,
## hotbar first. Returns how many did not fit.
func add(item: StringName, count: int) -> int:
	var limit: int = ItemTypes.TYPES[item]["stack_limit"]
	var left := count
	for slot in SLOT_COUNT:
		if left == 0:
			break
		if item_in(slot) == item:
			var moved := mini(left, limit - slots[slot]["count"])
			slots[slot]["count"] += moved
			left -= moved
	for slot in SLOT_COUNT:
		if left == 0:
			break
		if slots[slot].is_empty():
			var moved := mini(left, limit)
			slots[slot] = {"item": item, "count": moved}
			left -= moved
	changed.emit()
	return left


## Whether `add` would take all of `items` (item id to count) at once.
func can_add(items: Dictionary) -> bool:
	var trial := Inventory.from_dict(to_dict())
	for item: StringName in items:
		if trial.add(item, items[item]) > 0:
			return false
	return true


## Takes up to `count` of `item` out, from the last slots first. Returns how many were taken.
func remove(item: StringName, count: int) -> int:
	var left := count
	for slot in range(SLOT_COUNT - 1, -1, -1):
		if left == 0:
			break
		if item_in(slot) == item:
			var taken := mini(left, slots[slot]["count"])
			slots[slot]["count"] -= taken
			left -= taken
			if slots[slot]["count"] == 0:
				slots[slot] = {}
	changed.emit()
	return count - left


func count_of(item: StringName) -> int:
	var total := 0
	for stack in slots:
		if stack.get("item") == item:
			total += stack["count"]
	return total


## Moves what is in slot `from` to slot `to`. Stacks of the same item merge, up to the stack
## limit, and what doesn't fit stays in `from`; anything else swaps places.
func move(from: int, to: int) -> void:
	if from == to or slots[from].is_empty():
		return
	if item_in(from) == item_in(to):
		var limit: int = ItemTypes.TYPES[item_in(to)]["stack_limit"]
		var moved := mini(slots[from]["count"], limit - slots[to]["count"])
		slots[to]["count"] += moved
		slots[from]["count"] -= moved
		if slots[from]["count"] == 0:
			slots[from] = {}
	else:
		var other := slots[to]
		slots[to] = slots[from]
		slots[from] = other
	changed.emit()


func total_weight() -> float:
	var total := 0.0
	for stack in slots:
		if not stack.is_empty():
			total += stack["count"] * ItemTypes.TYPES[stack["item"]]["weight"]
	return total


func to_dict() -> Dictionary:
	var slots_data: Array = []
	for stack in slots:
		slots_data.append(
			null if stack.is_empty() else {"item": str(stack["item"]), "count": stack["count"]}
		)
	return {"slots": slots_data, "selected_slot": selected_slot}


static func from_dict(data: Dictionary) -> Inventory:
	var inventory := Inventory.new()
	var slots_data: Array = data["slots"]
	assert(slots_data.size() == SLOT_COUNT, "Wrong number of inventory slots in save")
	for slot in SLOT_COUNT:
		var stack: Variant = slots_data[slot]
		if stack != null:
			var item := StringName(stack["item"])
			assert(ItemTypes.TYPES.has(item), "Unknown item in save: %s" % item)
			inventory.slots[slot] = {"item": item, "count": int(stack["count"])}
	inventory.selected_slot = int(data["selected_slot"])
	return inventory
