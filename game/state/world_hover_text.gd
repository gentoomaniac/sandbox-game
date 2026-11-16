class_name WorldHoverText
extends RefCounted
## What the box by the cursor says about the world: who lives and works in the building the mouse
## is over (Households `occupants_text`), else how the crop or campfire on the target is doing, or
## the height and strength of the dyke (`object_text_at`), whether the mouse or the facing tile
## aims at it. A building only speaks to the mouse: facing one, the player stands at its door. ""
## for nothing, indoors, or when `is_on_world` is false (a window, the pointer on the UI, placing a
## building).


static func text_for(state: GameState, targeting: Targeting, is_on_world: bool) -> String:
	if not is_on_world or state.is_inside():
		return ""
	if targeting.source == Targeting.Source.MOUSE:
		var building := state.world.building_at(targeting.tile)
		if building != null:
			return state.homes.occupants_text(building)
	return object_text_at(state, targeting.tile)


## How the crop or the campfire at a tile is doing (see CropWords `state_text` and Campfire
## `state_text`), or "" where there is none.
static func object_text_at(state: GameState, tile: Vector2i) -> String:
	var crop := state.world.object_at(tile)
	if Campfire.is_campfire(crop):
		return Campfire.state_text(crop)
	if crop != null and crop.type == WorldObjectTypes.DYKE:
		return state.world.dykes.words(crop)
	if crop == null or not crop.is_crop():
		return ""
	var day_weather := state.weather.day_summary(crop.pos, state.clock.day)
	return CropWords.state_text(crop, day_weather, state.world.moisture_at(crop.pos))
