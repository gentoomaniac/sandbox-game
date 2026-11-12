class_name NeedSources
extends RefCounted
## What on the ground meets the needs of the farm animals (see Livestock): fresh water, a stock of
## water or a stock of feed, and taking a meal out of a stock. Plain functions on a map.


## Whether what is on a tile meets a need now: fresh water or a trough with water for thirst (a
## stock of kind water), a stock of feed (a hay rack, a feeding trough) for hunger.
static func gives(map: GameMap, pos: Vector2i, need: StringName) -> bool:
	var tile := map.tile_at(pos)
	if need == &"thirst" and tile != null and tile.is_fresh_water():
		return true
	var object := map.object_at(pos)
	if object == null or not ObjectStock.is_stocked(object) or ObjectStock.units(object) == 0:
		return false
	return object.type_data()["stock_kind"] == (&"water" if need == &"thirst" else &"feed")


## Takes `units` out of the stock of the object on a tile, if it has one, so that its picture
## follows; a tile of water has none to take.
static func take(map: GameMap, pos: Vector2i, units: int) -> void:
	var object := map.object_at(pos)
	if object != null and ObjectStock.is_stocked(object):
		ObjectStock.take(object, units)
		if map is World:
			(map as World).change_object(object)
