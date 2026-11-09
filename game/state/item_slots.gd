class_name ItemSlots
extends RefCounted
## A row of item slots: what the player carries (Inventory) or a chest holds (see
## WorldObject `storage`). Plain state; screens only show it and send it actions.
##
## A slot is empty (`{}`) or a stack `{item: StringName, count: int}`: an item id from
## ItemTypes and at most its stack limit.
##
## Every operation that changes the slots finishes the whole change first and only then sends
## `changed`, once per container involved, so a listener never sees an item twice or missing. An
## operation that is refused (a bad slot, a count below 1, too little of something) changes
## nothing.

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


func has_slot(slot: int) -> bool:
	return slot >= 0 and slot < slots.size()


func is_empty() -> bool:
	return slots.all(func(stack: Dictionary) -> bool: return stack.is_empty())


## Puts `count` of `item` in: first onto stacks of it that have room, then into free slots in
## the order of `free_slots` (empty: `_free_slot_order`). Returns how many did not fit (all of
## them for a count below 1).
func add(item: StringName, count: int, free_slots: Array = []) -> int:
	if count < 1:
		return count
	var left := _add(item, count, free_slots)
	changed.emit()
	return left


## Whether `add` would take all of `items` (item id to count) at once.
func can_add(items: Dictionary) -> bool:
	return can_exchange({}, items)


## Takes up to `count` of `item` out, from the last slots first. Returns how many were taken.
func remove(item: StringName, count: int) -> int:
	if count < 1:
		return 0
	var taken := _remove(item, count)
	changed.emit()
	return taken


## Takes `count` out of the stack in `slot`: that stack, not the last one of its item (what
## using the held item needs). Returns false and changes nothing for a bad slot, a bad count, or
## a stack with fewer than `count`.
func take_from(slot: int, count: int) -> bool:
	if not has_slot(slot) or count < 1 or slots[slot].get("count", 0) < count:
		return false
	slots[slot]["count"] -= count
	if slots[slot]["count"] == 0:
		slots[slot] = {}
	changed.emit()
	return true


## Whether `exchange` would work.
func can_exchange(paid: Dictionary, received: Dictionary) -> bool:
	var trial := ItemSlots.new(slots.size())
	trial.load_slots(slots_to_data())
	for item: StringName in paid:
		if paid[item] < 1 or trial._remove(item, paid[item]) < paid[item]:
			return false
	for item: StringName in received:
		if received[item] < 1 or trial._add(item, received[item], []) > 0:
			return false
	return true


## Takes `paid` out (item id to count, from wherever it lies) and puts `received` in, as one
## change: the paid items leave first, so full slots can still hold what they were made into.
## Returns false and changes nothing when the slots lack `paid` or `received` does not fit.
func exchange(paid: Dictionary, received: Dictionary) -> bool:
	if not can_exchange(paid, received):
		return false
	for item: StringName in paid:
		_remove(item, paid[item])
	for item: StringName in received:
		_add(item, received[item], [])
	changed.emit()
	return true


## Puts a single `item` in `slot`, replacing what is there; NONE empties the slot. For the
## equipment, which has already changed what it wears (see Equipment `move_to_equipment`).
func replace_with_one(slot: int, item: StringName) -> void:
	slots[slot] = {} if item == ItemTypes.NONE else {"item": item, "count": 1}
	changed.emit()


## Destroys the stack in `slot` for good (the trash can); the other slots stay as they are.
func destroy(slot: int) -> void:
	if not has_slot(slot):
		return
	slots[slot] = {}
	changed.emit()


## Moves what is in slot `from` to slot `to` of `target` (these slots themselves for a move
## inside). Stacks of the same item merge, up to the stack limit, and what doesn't fit stays in
## `from`; anything else swaps places. Returns whether it swapped two items, so `from` now holds
## the one that was in `to` (a screen lets that one stick to the mouse). Bad slots move nothing.
func move_to(from: int, target: ItemSlots, to: int) -> bool:
	if (
		not has_slot(from)
		or not target.has_slot(to)
		or (target == self and from == to)
		or slots[from].is_empty()
	):
		return false
	var is_swap := not target.slots[to].is_empty() and item_in(from) != target.item_in(to)
	if item_in(from) == target.item_in(to):
		var limit: int = ItemTypes.TYPES[item_in(from)]["stack_limit"]
		var moved := mini(slots[from]["count"], limit - target.slots[to]["count"])
		target.slots[to]["count"] += moved
		slots[from]["count"] -= moved
		if slots[from]["count"] == 0:
			slots[from] = {}
	else:
		var other := target.slots[to]
		target.slots[to] = slots[from]
		slots[from] = other
	_notify_with(target)
	return is_swap


## Moves the stack in slot `from` to `target`, as much of it as fits: onto stacks of the same
## item first, then into free slots (see `add` for `free_slots`). The rest stays. Returns
## whether the whole stack went. Sending to these slots themselves, or from a bad slot, moves
## nothing.
func send(from: int, target: ItemSlots, free_slots: Array = []) -> bool:
	if target == self or not has_slot(from) or slots[from].is_empty():
		return false
	var left: int = target._add(slots[from]["item"], slots[from]["count"], free_slots)
	slots[from]["count"] = left
	if left == 0:
		slots[from] = {}
	_notify_with(target)
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


## `add` without the notification, for the operations that send `changed` once when they are
## done.
func _add(item: StringName, count: int, free_slots: Array) -> int:
	var limit: int = ItemTypes.TYPES[item]["stack_limit"]
	var left := count
	for slot in slots.size():
		if left == 0:
			break
		if item_in(slot) == item:
			var moved := mini(left, limit - slots[slot]["count"])
			slots[slot]["count"] += moved
			left -= moved
	for slot: int in free_slots if not free_slots.is_empty() else _free_slot_order():
		if left == 0:
			break
		if slots[slot].is_empty():
			var moved := mini(left, limit)
			slots[slot] = {"item": item, "count": moved}
			left -= moved
	return left


## `remove` without the notification.
func _remove(item: StringName, count: int) -> int:
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
	return count - left


## Tells of a change made to these slots and `other` together, once both are done.
func _notify_with(other: ItemSlots) -> void:
	changed.emit()
	if other != self:
		other.changed.emit()
