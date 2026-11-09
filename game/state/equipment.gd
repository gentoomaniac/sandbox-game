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
## Worn over the body: a jacket or a coat.
const COAT := &"coat"
const BACK := &"back"
const MAIN_HAND := &"main_hand"
const OFF_HAND := &"off_hand"

const SLOTS := [HEAD, BODY, LEGS, FEET, COAT, BACK, MAIN_HAND, OFF_HAND]

## Slot to item id; a slot without an item has no key.
var _worn := {}


## What a new game starts with, and what a save from before equipment is given. (A function,
## not a constant: ItemTypes needs this class's slot names for its own constants.)
static func with_starting_outfit() -> Equipment:
	var equipment := Equipment.new()
	equipment.equip(BODY, ItemTypes.WAISTCOAT)
	equipment.equip(LEGS, ItemTypes.BREECHES)
	equipment.equip(FEET, ItemTypes.CLOGS)
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


## Destroys what is worn in `slot` for good (the trash can).
func destroy(slot: StringName) -> void:
	unequip(slot)


## Moves the item in inventory slot `from` onto `slot`; what was worn there goes to `from`.
## Both sides are done before either one sends `changed`.
func move_to_equipment(inventory: Inventory, from: int, slot: StringName) -> bool:
	if not inventory.has_slot(from) or not fits(slot, inventory.item_in(from)):
		return false
	var item := inventory.item_in(from)
	var previous := item_in(slot)
	_worn[slot] = item
	inventory.replace_with_one(from, previous)
	changed.emit()
	return true


## Moves what is worn in `slot` to inventory slot `to`: onto a free slot, or swapping with
## an item there that fits `slot`. Both sides are done before either one sends `changed`.
func move_to_inventory(inventory: Inventory, slot: StringName, to: int) -> bool:
	if not inventory.has_slot(to):
		return false
	var worn := item_in(slot)
	var other := inventory.item_in(to)
	if worn == ItemTypes.NONE or (other != ItemTypes.NONE and not fits(slot, other)):
		return false
	if other == ItemTypes.NONE:
		_worn.erase(slot)
	else:
		_worn[slot] = other
	inventory.replace_with_one(to, worn)
	changed.emit()
	return true


## Right click on an inventory slot: wears its item in the slot it fits.
func quick_equip(inventory: Inventory, from: int) -> bool:
	return move_to_equipment(inventory, from, slot_of(inventory.item_in(from)))


## Right click on an equipment slot: takes the item off into the first free inventory slot.
func quick_unequip(inventory: Inventory, slot: StringName) -> bool:
	for to in Inventory.SLOT_COUNT:
		if inventory.item_in(to) == ItemTypes.NONE:
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
		# `equip` asserts that the item exists and fits: the SaveValidator has seen to that.
		equipment.equip(StringName(slot), item)
	return equipment
