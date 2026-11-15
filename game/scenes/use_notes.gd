class_name UseNotes
extends RefCounted
## What the note says about a use of the held item, for the uses that have one.

## What the player is told when they try on horseback what needs them on foot.
const GET_OFF_FIRST := "Get off the horse first."
const _NOTES := {
	ToolUse.Use.GIVE_BONE: "The dog follows you.",
	ToolUse.Use.SADDLE: "The horse is saddled: E to get on.",
	ToolUse.Use.UNSADDLE: "You take the saddle off.",
	ToolUse.Use.FILL_CAN: "You fill the watering can.",
	ToolUse.Use.CAN_EMPTY: "The watering can is empty: fill it at a well or at fresh water.",
	ToolUse.Use.RIDING: GET_OFF_FIRST,
	ToolUse.Use.NO_ROOM: "Not enough room in the inventory.",
	ToolUse.Use.STANDING_ON: "Step off it first.",
	ToolUse.Use.THE_VILLAGES: GameState.THE_VILLAGES,
}


## The note for `use` of the item held in `inventory`, or "" if it has none.
static func of(use: ToolUse.Use, inventory: Inventory) -> String:
	if use == ToolUse.Use.NEEDS_BETTER_TOOL:
		return "Needs a better %s." % ItemTypes.tool_name(inventory.held_item())
	return _NOTES.get(use, "")
