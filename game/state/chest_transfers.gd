class_name ChestTransfers
extends RefCounted
## The player moving goods between their backpack and a chest. Whatever leaves the chest is
## reported at once, after the move is done, as a TAKE_FROM_CHEST outcome (a stealing if the chest
## is a villager's, see Harm), so the witnesses are those who are there when the goods are taken.
## A move that is refused reports nothing, and so does a swap or a move into the chest that takes
## nothing out of it. Goods put back do not undo what was reported: whoever saw the taking saw it.

var _state: GameState
var _chest: WorldObject


func _init(state: GameState, chest: WorldObject) -> void:
	assert(chest.storage != null, "Not a chest: %s" % chest.type)
	_state = state
	_chest = chest


## A stack dragged from slot `from` of `source` onto slot `to` of `target`, two of the backpack's
## or the chest's slots (see ItemSlots `move_to`).
func drag(source: ItemSlots, from: int, target: ItemSlots, to: int) -> void:
	_reporting_taken(func() -> void: source.move_to(from, target, to))


## Shift+click on a chest slot: the stack goes to the backpack first, so the hotbar isn't
## flooded.
func take_to_backpack(slot: int) -> void:
	var inventory := _state.player.inventory
	_reporting_taken(
		func() -> void: _chest.storage.send(slot, inventory, inventory.backpack_first_order())
	)


## Shift+click on a backpack or hotbar slot: the stack goes into the chest.
func put_in(inventory_slot: int) -> void:
	_state.player.inventory.send(inventory_slot, _chest.storage)


## The stack in `slot` of the chest is destroyed (the trash can): it is gone from the chest, so it
## is taken from it.
func destroy(slot: int) -> void:
	_reporting_taken(func() -> void: _chest.storage.destroy(slot))


## Runs `move` and reports what the chest holds less of afterwards.
func _reporting_taken(move: Callable) -> void:
	var held_before := _chest.storage.totals()
	move.call()
	var held_now := _chest.storage.totals()
	var taken := {}
	for item: StringName in held_before:
		var count: int = held_before[item] - held_now.get(item, 0)
		if count > 0:
			taken[item] = count
	if not taken.is_empty():
		_state.report(ActionOutcome.TAKE_FROM_CHEST, _chest.pos, _chest.type, taken)
