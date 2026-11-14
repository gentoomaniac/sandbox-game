class_name WorldHoverText
extends RefCounted
## What the box by the cursor says about the world: who lives and works in the building the mouse
## is over (Households `occupants_text`), else how the crop or campfire on the target is doing
## (GameState `object_text_at`), whether the mouse or the facing tile aims at it. A building only
## speaks to the mouse: facing one, the player stands at its door. "" for nothing, indoors, or
## when `is_on_world` is false (a window, the pointer on the UI, placing a building).


static func text_for(state: GameState, targeting: Targeting, is_on_world: bool) -> String:
	if not is_on_world or state.is_inside():
		return ""
	if targeting.source == Targeting.Source.MOUSE:
		var building := state.world.building_at(targeting.tile)
		if building != null:
			return state.homes.occupants_text(building)
	return state.object_text_at(targeting.tile)
