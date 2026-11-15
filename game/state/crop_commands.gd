class_name CropCommands
extends RefCounted
## What the console's `crop` says: how the crop in front of the player (or the nearest one) grows,
## and the soil's moisture under it.

## How far (in tiles) `crop` looks for a crop when none is in front of the player.
const SEARCH_RADIUS := 4


static func crop(state: GameState) -> Array[String]:
	var found := nearest_crop(state)
	if found == null:
		return ["No crop near you"]
	var lines: Array[String] = []
	lines.assign(CropLife.describe(found))
	lines.append("Soil moisture %.2f" % state.world.moisture_at(found.pos))
	return lines


## The crop in front of the player, else the nearest one within SEARCH_RADIUS.
static func nearest_crop(state: GameState) -> WorldObject:
	if state.is_inside():
		return null
	var in_front := state.world.object_at(state.player.facing_tile())
	if in_front != null and in_front.is_crop():
		return in_front
	var nearest: WorldObject = null
	var player_tile := state.player.tile()
	for y in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
		for x in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
			var object := state.world.object_at(player_tile + Vector2i(x, y))
			if object == null or not object.is_crop():
				continue
			if (
				nearest == null
				or Vector2i(x, y).length_squared() < (nearest.pos - player_tile).length_squared()
			):
				nearest = object
	return nearest
