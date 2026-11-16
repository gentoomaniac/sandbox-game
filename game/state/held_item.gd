class_name HeldItem
extends RefCounted
## What the player does with the item in hand that is not a tool use (see ToolUse): eating food and
## lighting, putting out or fitting a candle in the lantern. Keeps nothing: every function is given
## the game, and tells it what was done (see GameState `report`).

## What using the held lantern does (see `lantern_use`).
enum LanternUse { NONE, PUT_OUT, LIGHT, FIT_CANDLE }


## What the lantern in hand does when used (see `switch_lantern`): lit, it is put out; with a
## candle in it, it is lit; with none, the freshest candle of the inventory is fitted (and it stays
## dark); with none to fit, or with no lantern in hand, nothing.
static func lantern_use(state: GameState) -> LanternUse:
	var inventory := state.player.inventory
	if inventory.held_item() != ItemTypes.LANTERN:
		return LanternUse.NONE
	if LanternCandle.holds_candle(inventory.slots[inventory.selected_slot]):
		return LanternUse.PUT_OUT if state.player.is_lantern_lit else LanternUse.LIGHT
	return LanternUse.FIT_CANDLE if inventory.freshest_candle_slot() != -1 else LanternUse.NONE


## Uses the held lantern, on any map, also on horseback (see `lantern_use`). Does nothing, and
## returns false, when that is NONE.
static func switch_lantern(state: GameState) -> bool:
	var player := state.player
	var use := lantern_use(state)
	match use:
		LanternUse.NONE:
			return false
		LanternUse.FIT_CANDLE:
			player.inventory.fit_candle(player.inventory.selected_slot)
			player.is_lantern_lit = false
		_:
			player.is_lantern_lit = use == LanternUse.LIGHT
	state.report(ActionOutcome.SWITCH_LANTERN, player.tile(), &"", {ItemTypes.LANTERN: 1})
	return true


## Whether the held item is food and the energy is below the cap, so that `eat` eats it.
static func can_eat(state: GameState) -> bool:
	return (
		state.energy_rules.is_food(state.player.inventory.held_item())
		and state.player.energy < state.energy_cap()
	)


## Eats one of the held food, on any map: it restores energy up to the cap. Does nothing, and
## returns false, unless `can_eat`.
static func eat(state: GameState) -> bool:
	if not can_eat(state):
		return false
	var player := state.player
	var food := player.inventory.held_item()
	player.inventory.consume_held()
	player.energy = minf(player.energy + state.energy_rules.food_restore(food), state.energy_cap())
	state.report(ActionOutcome.EAT, player.tile(), &"", {food: 1})
	return true
