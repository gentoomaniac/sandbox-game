class_name Inventory
extends ItemSlots
## What the player carries: the hotbar (slots 0 to HOTBAR_SIZE - 1), one of which is selected:
## that item is held, and after it the backpack (BACKPACK_SIZE slots). The hotbar is extra room,
## it takes nothing from the backpack. Plain state; the hotbar and the inventory screen only
## show it and send it actions. `changed` also tells of the selection changing.

const HOTBAR_SIZE := 8
const BACKPACK_SIZE := 20
const SLOT_COUNT := HOTBAR_SIZE + BACKPACK_SIZE

## What a new game starts with: item and count, in slot order.
const STARTING_ITEMS := [
	[ItemTypes.RUSTY_IRON_HOE, 1],
	[ItemTypes.RUSTY_IRON_AXE, 1],
	[ItemTypes.RUSTY_IRON_PICKAXE, 1],
	[ItemTypes.RUSTY_IRON_WATERING_CAN, 1],
	[ItemTypes.TURNIP_SEEDS, 15],
	[ItemTypes.RUSTY_IRON_SCYTHE, 1],
	[ItemTypes.RUSTY_IRON_SHOVEL, 1],
	[ItemTypes.RUSTY_IRON_HAMMER, 1],
]
## What a new game starts with in the backpack (from the slot after the hotbar), so the hotbar
## keeps room for what the player picks up.
## A new game carries only the outfit (tools weigh nothing), far under the weight that costs no
## extra energy (data/energy.cfg), and the energy tests count on that: mind it when adding here.
const STARTING_BACKPACK := [
	[ItemTypes.STRAW_HAT, 1],
	[ItemTypes.KNITTED_CAP, 1],
	[ItemTypes.SHIRT, 1],
	[ItemTypes.JACKET, 1],
]

## The hotbar slot the player holds.
var selected_slot := 0
## The water in the watering can (see PlayerState `can_water`), kept here so that the hotbar shows
## it on the can when it changes.
var can_water := EnergyRules.default_rules().can_capacity():
	set(value):
		can_water = value
		changed.emit()


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


## Uses up one of the held item: it comes out of the selected slot, not out of the last stack of
## that item. Returns false when the hand is empty.
func consume_held() -> bool:
	return take_from(selected_slot, 1)


func select(hotbar_slot: int) -> void:
	assert(hotbar_slot >= 0 and hotbar_slot < HOTBAR_SIZE, "Not a hotbar slot: %d" % hotbar_slot)
	selected_slot = hotbar_slot
	changed.emit()


## Puts `item` in the hand (ItemTypes.NONE for an empty hand): selects its hotbar slot, or, if it
## is not on the hotbar (which has no free slot at the start), swaps the first stack of it into the
## selected slot. An item the inventory doesn't have yet is added first.
func hold(item: StringName) -> void:
	for slot in HOTBAR_SIZE:
		if item_in(slot) == item:
			select(slot)
			return
	var has_item := func(stack: Dictionary) -> bool:
		return stack.get("item", ItemTypes.NONE) == item
	var source := slots.find_custom(has_item)
	if source == -1:
		add(item, 1)
		source = slots.find_custom(has_item)
	var displaced := slots[selected_slot]
	slots[selected_slot] = slots[source]
	slots[source] = displaced
	changed.emit()


## Selects the hotbar slot `steps` along from the selected one (back if negative), round from
## the last slot to the first and back: the mouse wheel's step.
func select_next(steps: int) -> void:
	select(posmod(selected_slot + steps, HOTBAR_SIZE))


func total_weight() -> float:
	var total := 0.0
	for stack in slots:
		if not stack.is_empty():
			total += stack["count"] * ItemTypes.TYPES[stack["item"]]["weight"]
	return total


func to_dict() -> Dictionary:
	return {"slots": slots_to_data(), "selected_slot": selected_slot}


static func from_dict(data: Dictionary) -> Inventory:
	var inventory := Inventory.new()
	inventory.load_slots(data["slots"])
	inventory.select(int(data["selected_slot"]))
	return inventory


## What a pickup, a harvest, a crafted item or anything else the player gains fills, in order:
## the stacks of the item on the hotbar, the free hotbar slots, the stacks in the backpack, the
## free backpack slots, and the selected slot only if it is empty and nothing else is left (so an
## empty hand stays empty after a harvest; a held stack of the item still fills in turn). With
## `free_slots` given (a chest take) the plain order applies.
func _add(item: StringName, count: int, free_slots: Array, state := {}) -> int:
	if not free_slots.is_empty():
		return super(item, count, free_slots, state)
	var hotbar := range(HOTBAR_SIZE)
	var backpack := range(HOTBAR_SIZE, SLOT_COUNT)
	var free_hotbar := hotbar.filter(func(slot: int) -> bool: return slot != selected_slot)
	var left := _put(item, count, hotbar, free_hotbar, state)
	left = _put(item, left, backpack, backpack, state)
	return _put(item, left, [], [selected_slot], state)


## Whether `plain` (item id to count) and each of the single items `stacks` with their states
## (what a chest taken down holds) would all fit, as `add` puts them in.
func can_take(plain: Dictionary, stacks: Array[Dictionary]) -> bool:
	var trial := _new_trial()
	trial.load_slots(slots_to_data())
	for item: StringName in plain:
		if trial._add(item, plain[item], []) > 0:
			return false
	for stack in stacks:
		if trial._add(stack["item"], 1, [], stack["state"]) > 0:
			return false
	return true


## Fits a candle from the inventory into the lantern in `slot` that has none: the freshest one
## the inventory has. Returns whether it did.
func fit_candle(slot: int) -> bool:
	if item_in(slot) != ItemTypes.LANTERN or LanternCandle.holds_candle(slots[slot]):
		return false
	var freshest := -1
	for candidate in SLOT_COUNT:
		if (
			item_in(candidate) == ItemTypes.CANDLE
			and (freshest == -1 or _burnt_in(candidate) < _burnt_in(freshest))
		):
			freshest = candidate
	if freshest == -1:
		return false
	var candle_state: Dictionary = slots[freshest].get("state", {})
	hold_notifications(
		func() -> void:
			take_from(freshest, 1)
			set_state(slot, LanternCandle.lantern_state_with(candle_state))
	)
	return true


## Takes the candle out of the lantern in `slot`, as it is, into the inventory. Returns false and
## changes nothing if it holds none or the candle has no room.
func take_candle_out(slot: int) -> bool:
	if not LanternCandle.holds_candle(slots[slot]):
		return false
	var candle_state: Dictionary = slots[slot]["state"][LanternCandle.CANDLE]
	if _add(ItemTypes.CANDLE, 1, [], candle_state) > 0:
		return false
	set_state(slot, {})
	return true


## Burns the candle of the lantern in `slot` down by `minutes`. A candle that burns out is gone.
## Returns whether it did.
func burn_candle(slot: int, minutes: int) -> bool:
	var candle_state: Dictionary = slots[slot]["state"][LanternCandle.CANDLE]
	candle_state = LanternCandle.burnt_for(candle_state, minutes)
	var is_burnt_out := LanternCandle.is_burnt_out(candle_state)
	set_state(slot, {} if is_burnt_out else LanternCandle.lantern_state_with(candle_state))
	return is_burnt_out


func _burnt_in(slot: int) -> int:
	return LanternCandle.burnt_minutes(slots[slot].get("state", {}))


func _new_trial() -> ItemSlots:
	var trial := Inventory.new()
	trial.selected_slot = selected_slot
	return trial


## The free slots, hotbar first and the selected slot last.
func _free_slot_order() -> Array:
	var order := super()
	order.erase(selected_slot)
	order.append(selected_slot)
	return order


## Shift+click: moves the stack in `slot` from the hotbar into the backpack or the other way
## round, onto stacks of the same item there first, then into the first free slot. What does not
## fit stays in `slot`. Returns whether the whole stack went.
func move_to_other_part(slot: int) -> bool:
	var part := range(HOTBAR_SIZE, SLOT_COUNT) if slot < HOTBAR_SIZE else range(HOTBAR_SIZE)
	return move_into(slot, part)


## The free slots for something coming out of a chest: the backpack before the hotbar, so the
## hotbar isn't flooded.
func backpack_first_order() -> Array:
	var order := _free_slot_order()
	var backpack := order.filter(func(slot: int) -> bool: return slot >= HOTBAR_SIZE)
	var hotbar := order.filter(func(slot: int) -> bool: return slot < HOTBAR_SIZE)
	return backpack + hotbar
