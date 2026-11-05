class_name ItemSlots
extends RefCounted
## A row of item slots: what the player carries (Inventory) or a chest holds (see
## WorldObject `storage`). Plain state; screens only show it and send it actions.
##
## A slot is empty (`{}`) or a stack `{item: StringName, count: int}`: an item id from
## ItemTypes and at most its stack limit.

## Whenever a slot changes.
signal changed

var slots: Array[Dictionary] = []


func _init(slot_count: int) -> void:
	for slot in slot_count:
		slots.append({})


func item_in(slot: int) -> StringName:
	return slots[slot].get("item", ItemTypes.NONE)


func count_of(item: StringName) -> int:
	var total := 0
	for stack in slots:
		if stack.get("item") == item:
			total += stack["count"]
	return total


## Everything in the slots, item id to count.
func totals() -> Dictionary:
	var totals_by_item := {}
	for stack in slots:
		if not stack.is_empty():
			totals_by_item[stack["item"]] = totals_by_item.get(stack["item"], 0) + stack["count"]
	return totals_by_item


func is_empty() -> bool:
	return slots.all(func(stack: Dictionary) -> bool: return stack.is_empty())


## Puts `count` of `item` in: first onto stacks of it that have room, then into free slots in
## the order of `_free_slot_order`. Returns how many did not fit.
func add(item: StringName, count: int) -> int:
	var limit: int = ItemTypes.TYPES[item]["stack_limit"]
	var left := count
	for slot in slots.size():
		if left == 0:
			break
		if item_in(slot) == item:
			var moved := mini(left, limit - slots[slot]["count"])
			slots[slot]["count"] += moved
			left -= moved
	for slot: int in _free_slot_order():
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
	var trial := ItemSlots.new(slots.size())
	trial.load_slots(slots_to_data())
	for item: StringName in items:
		if trial.add(item, items[item]) > 0:
			return false
	return true


## Takes up to `count` of `item` out, from the last slots first. Returns how many were taken.
func remove(item: StringName, count: int) -> int:
	var left := count
	for slot in range(slots.size() - 1, -1, -1):
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


## Moves what is in slot `from` to slot `to` of `target` (these slots themselves for a move
## inside). Stacks of the same item merge, up to the stack limit, and what doesn't fit stays in
## `from`; anything else swaps places.
func move_to(from: int, target: ItemSlots, to: int) -> void:
	if (target == self and from == to) or slots[from].is_empty():
		return
	if item_in(from) == target.item_in(to):
		var limit: int = ItemTypes.TYPES[item_in(to)]["stack_limit"]
		var moved := mini(slots[from]["count"], limit - target.slots[to]["count"])
		target.slots[to]["count"] += moved
		slots[from]["count"] -= moved
		if slots[from]["count"] == 0:
			slots[from] = {}
	else:
		var other := target.slots[to]
		target.slots[to] = slots[from]
		slots[from] = other
	changed.emit()
	if target != self:
		target.changed.emit()


## Moves the stack in slot `from` to `target`, as much of it as fits: onto stacks of the same
## item first, then into free slots. The rest stays. Returns whether the whole stack went.
func send(from: int, target: ItemSlots) -> bool:
	if slots[from].is_empty():
		return false
	var left := target.add(slots[from]["item"], slots[from]["count"])
	slots[from]["count"] = left
	if left == 0:
		slots[from] = {}
	changed.emit()
	return left == 0


## The slots as plain data for a save: null for an empty slot.
func slots_to_data() -> Array:
	var slots_data: Array = []
	for stack in slots:
		slots_data.append(
			null if stack.is_empty() else {"item": str(stack["item"]), "count": stack["count"]}
		)
	return slots_data


## Replaces the slots with saved ones (see `slots_to_data`); there must be as many.
func load_slots(slots_data: Array) -> void:
	assert(slots_data.size() == slots.size(), "Wrong number of item slots in save")
	for slot in slots.size():
		var stack: Variant = slots_data[slot]
		slots[slot] = {}
		if stack != null:
			var item := StringName(stack["item"])
			assert(ItemTypes.TYPES.has(item), "Unknown item in save: %s" % item)
			slots[slot] = {"item": item, "count": int(stack["count"])}


## The slots to fill when an item has no stack to join, in order of preference.
func _free_slot_order() -> Array:
	return range(slots.size())
