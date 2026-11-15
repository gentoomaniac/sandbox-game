extends ConsoleCommand

## How far (in tiles) `crop` looks for a crop when none is in front of the player.
const SEARCH_RADIUS := 4


func name() -> String:
	return "crop"


func usage() -> String:
	return "crop"


func help() -> String:
	return "Show the growth, damage and needs of the crop in front of you or the nearest one."


func run(_arguments: PackedStringArray) -> Array[String]:
	var found := _nearest_crop()
	if found == null:
		return ["No crop near you"]
	var lines: Array[String] = []
	lines.assign(CropLife.describe(found))
	lines.append("Soil moisture %.2f" % context.state.world.moisture_at(found.pos))
	return lines


## The crop in front of the player, else the nearest one within SEARCH_RADIUS.
func _nearest_crop() -> WorldObject:
	var state := context.state
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
