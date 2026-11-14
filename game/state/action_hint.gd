class_name ActionHint
extends RefCounted
## The words that name what E and the use action will do on a target tile, for the hint over the
## hotbar. They ask the rules that do it (Interaction `choice_at`, ToolUse `use_at`, GameState
## `can_eat_held`), so the hint can't differ from the action. An empty text means there is nothing
## to say. Plain logic on the GameState it is given.

## What each use of the held item is called, for the uses worth naming. The others (nothing to do,
## a tool too weak, riding, ...) say nothing; a tool of the player's is named in `use_text`.
const USE_WORDS := {
	ToolUse.Use.TILL: "Till",
	ToolUse.Use.PLANT: "Plant",
	ToolUse.Use.HARVEST: "Harvest",
	ToolUse.Use.FORAGE: "Pick",
	ToolUse.Use.HIT: "Hit",
	ToolUse.Use.CLEAR: "Clear the dead crop",
	ToolUse.Use.WATER: "Water",
	ToolUse.Use.FILL_CAN: "Refill",
	ToolUse.Use.POUR: "Pour water",
	ToolUse.Use.FEED: "Feed",
	ToolUse.Use.COLLECT: "Collect the eggs",
	ToolUse.Use.MOW: "Mow",
	ToolUse.Use.DIG: "Dig",
	ToolUse.Use.DIG_UP: "Dig up",
	ToolUse.Use.TAKE_DOWN: "Take down",
	ToolUse.Use.GIVE_BONE: "Give the bone",
	ToolUse.Use.SADDLE: "Saddle the horse",
	ToolUse.Use.UNSADDLE: "Remove saddle",
	ToolUse.Use.PET: "Pet",
}
## What using the held lantern is called, for the uses that do something.
const LANTERN_WORDS := {
	GameState.LanternUse.PUT_OUT: "Put out the lantern",
	GameState.LanternUse.LIGHT: "Light the lantern",
	GameState.LanternUse.FIT_CANDLE: "Fit a candle",
}


## What E does on `target`, as "Talk to Antje", or "".
static func e_text(state: GameState, target: Vector2i) -> String:
	var choice := Interaction.choice_at(state, target)
	match choice.kind:
		Interaction.Kind.DISMOUNT:
			return "Get off the horse"
		Interaction.Kind.CHAT:
			return "Talk to %s" % choice.subject.name
		Interaction.Kind.MOUNT:
			return "Get on the horse"
		Interaction.Kind.OPEN_STATION_GRID:
			return "Use %s" % _name_of(choice.subject)
		Interaction.Kind.OPEN_CHEST:
			return "Open %s" % _name_of(choice.subject)
		Interaction.Kind.OPEN_FIRE:
			return "Tend the fire"
		Interaction.Kind.OPEN_CRAFTING:
			return "Craft at %s" % _name_of(choice.subject)
		Interaction.Kind.RING_BELL:
			return "Ring the bell"
		Interaction.Kind.SLEEP:
			return "Sleep"
	return ""


## What the use key does with the held item on `target`, as "Harvest", or "". Eating and the lantern
## come first, as they do when the key is pressed (see Main); a tile out of reach is not used.
static func use_text(state: GameState, target: Vector2i) -> String:
	var held := state.player.inventory.held_item()
	if state.can_eat_held():
		return "Eat"
	var lantern_use := state.held_lantern_use()
	if lantern_use != GameState.LanternUse.NONE:
		return LANTERN_WORDS[lantern_use]
	var tool_use := ToolUse.new(state)
	if not tool_use.is_in_reach(target):
		return ""
	var use := tool_use.use_at(target)
	if use == ToolUse.Use.PLACE:
		return "Place the %s" % ItemTypes.TYPES[held]["name"].to_lower()
	if use == ToolUse.Use.GATE:
		var is_open := state.world.object_at(target).type == WorldObjectTypes.PEN_GATE_OPEN
		return "Shut the gate" if is_open else "Open the gate"
	if use == ToolUse.Use.NOTHING and held != ItemTypes.NONE and _is_ripe_crop_at(state, target):
		return _empty_hand_advice(state.player.inventory)
	return USE_WORDS.get(use, "")


## A crop is picked with an empty hand, which a player with the hotbar full of items can't see how
## to make: a free slot is selected, or an item is moved off the hotbar first.
static func _empty_hand_advice(inventory: Inventory) -> String:
	var has_free_slot := range(Inventory.HOTBAR_SIZE).any(
		func(slot: int) -> bool: return inventory.item_in(slot) == ItemTypes.NONE
	)
	if has_free_slot:
		return "Harvest with an empty hand: pick a free hotbar slot"
	return "Harvest with an empty hand: move an item off the hotbar"


static func _is_ripe_crop_at(state: GameState, target: Vector2i) -> bool:
	var crop := state.world.object_at(target)
	return crop != null and crop.is_crop() and CropLife.is_ripe(crop)


static func _name_of(object: WorldObject) -> String:
	return String(object.type).replace("_", " ")
