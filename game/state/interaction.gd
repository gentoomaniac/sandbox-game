class_name Interaction
extends RefCounted
## What the player's E acts on: the beds and chests within REACH tiles of them. Plain rules; Main
## asks and then sleeps or opens the storage screen.

## How far (in tiles, diagonals included) from the player's tile E reaches: the 3x3 tiles round
## them, their own included.
const REACH := 1


## The nearest object on the player's map within reach that `is_wanted` says yes to, or null.
static func nearest_in_reach(state: GameState, is_wanted: Callable) -> WorldObject:
	var player_tile := state.player.tile()
	var nearest: WorldObject = null
	for y in range(-REACH, REACH + 1):
		for x in range(-REACH, REACH + 1):
			var object := state.current_map.object_at(player_tile + Vector2i(x, y))
			if object == null or not is_wanted.call(object):
				continue
			if nearest == null or _distance(state, object) < _distance(state, nearest):
				nearest = object
	return nearest


## The chest E opens, or null. A chest on `target` (the targeted tile) wins; with a bed in reach
## the player sleeps instead, and without one the nearest chest in reach is opened.
static func chest_to_open(state: GameState, target: Vector2i) -> WorldObject:
	var targeted := state.current_map.object_at(target)
	var offset := (target - state.player.tile()).abs()
	if targeted != null and targeted.storage != null and maxi(offset.x, offset.y) <= REACH:
		return targeted
	if state.bed_in_reach() != null:
		return null
	return nearest_in_reach(state, func(object: WorldObject) -> bool: return object.storage != null)


static func _distance(state: GameState, object: WorldObject) -> float:
	return (Vector2(object.pos) + Vector2(0.5, 0.5)).distance_to(state.player.position)
