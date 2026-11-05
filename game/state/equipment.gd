class_name Equipment
extends RefCounted
## What the player wears and holds: one item (or none) in each of the equipment SLOTS. An
## item fits a slot when its ItemTypes entry names that slot as its `equip_slot`. Plain state;
## the character screen shows it and sends it actions. Items move between the inventory and
## the slots with the `move_*` and `quick_*` functions, which return false and change nothing
## when the move does not work.

## Whenever a slot changes.
signal changed

const HEAD := &"head"
const BODY := &"body"
const LEGS := &"legs"
const FEET := &"feet"
const BACK := &"back"
const MAIN_HAND := &"main_hand"
const OFF_HAND := &"off_hand"

const SLOTS := [HEAD, BODY, LEGS, FEET, BACK, MAIN_HAND, OFF_HAND]

## Slot to item id; a slot without an item has no key.
var _worn := {}


## What a new game starts with, and what a save from before equipment is given. (A function,
## not a constant: ItemTypes needs this class's slot names for its own constants.)
static func with_starting_outfit() -> Equipment:
	var equipment := Equipment.new()
	equipment.equip(BODY, ItemTypes.TUNIC)
	equipment.equip(LEGS, ItemTypes.TROUSERS)
	return equipment


## The slot `item` is worn in, or NONE if it is not wearable.
static func slot_of(item: StringName) -> StringName:
	return ItemTypes.TYPES.get(item, {}).get("equip_slot", ItemTypes.NONE)


static func fits(slot: StringName, item: StringName) -> bool:
	return slot in SLOTS and slot_of(item) == slot


func item_in(slot: StringName) -> StringName:
	return _worn.get(slot, ItemTypes.NONE)


## Puts `item` on, in the slot it fits; whatever was worn there is lost, so unequip first
## to keep it.
func equip(slot: StringName, item: StringName) -> void:
	assert(fits(slot, item), "%s does not fit the %s slot" % [item, slot])
	_worn[slot] = item
	changed.emit()


## Takes off what is worn in `slot` and returns it (NONE if the slot was empty).
func unequip(slot: StringName) -> StringName:
	var item := item_in(slot)
	_worn.erase(slot)
	changed.emit()
	return item


## Moves the item in inventory slot `from` onto `slot`; what was worn there goes to `from`.
func move_to_equipment(inventory: Inventory, from: int, slot: StringName) -> bool:
	var item := inventory.item_in(from)
	if not fits(slot, item):
		return false
	var previous := unequip(slot)
	inventory.slots[from] = {} if previous == ItemTypes.NONE else {"item": previous, "count": 1}
	equip(slot, item)
	inventory.changed.emit()
	return true


## Moves what is worn in `slot` to inventory slot `to`: onto a free slot, or swapping with
## an item there that fits `slot`.
func move_to_inventory(inventory: Inventory, slot: StringName, to: int) -> bool:
	var worn := item_in(slot)
	var other := inventory.item_in(to)
	if worn == ItemTypes.NONE or (other != ItemTypes.NONE and not fits(slot, other)):
		return false
	unequip(slot)
	if other != ItemTypes.NONE:
		equip(slot, other)
	inventory.slots[to] = {"item": worn, "count": 1}
	inventory.changed.emit()
	return true


## Right click on an inventory slot: wears its item in the slot it fits.
func quick_equip(inventory: Inventory, from: int) -> bool:
	return move_to_equipment(inventory, from, slot_of(inventory.item_in(from)))


## Right click on an equipment slot: takes the item off into the first free inventory slot.
func quick_unequip(inventory: Inventory, slot: StringName) -> bool:
	for to in Inventory.SLOT_COUNT:
		if inventory.slots[to].is_empty():
			return move_to_inventory(inventory, slot, to)
	return false


func total_weight() -> float:
	var total := 0.0
	for item: StringName in _worn.values():
		total += ItemTypes.TYPES[item]["weight"]
	return total


func to_dict() -> Dictionary:
	var worn_data := {}
	for slot: StringName in _worn:
		worn_data[str(slot)] = str(_worn[slot])
	return worn_data


static func from_dict(data: Dictionary) -> Equipment:
	var equipment := Equipment.new()
	for slot: String in data:
		var item := StringName(data[slot])
		# An item type that was removed since the save must not stop it from loading.
		if ItemTypes.TYPES.has(item) and fits(StringName(slot), item):
			equipment.equip(StringName(slot), item)
		else:
			push_warning("Dropped %s from slot %s of the save" % [item, slot])
	return equipment
