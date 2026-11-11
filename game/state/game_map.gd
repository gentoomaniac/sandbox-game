class_name GameMap
extends RefCounted
## A place the player can walk around in: the world or the inside of a building. Both are
## made of Tile state and WorldObjects, so walking and sleeping work the same on either. A
## subclass says where its tiles and objects are.

## An object was added, removed or changed on this tile of the map: one signal for each tile it
## covers. The views of the map redraw it; they need not know what did it.
signal objects_changed(pos: Vector2i)
## The terrain of this tile changed (World also tells of its grass wearing to a path).
signal tile_changed(pos: Vector2i)


## The tile at a position, or null where there is none.
func tile_at(_pos: Vector2i) -> Tile:
	return null


## The object on a tile, or null.
func object_at(_pos: Vector2i) -> WorldObject:
	return null


## Whether a one tile object can be put on a tile.
func is_placeable(_pos: Vector2i) -> bool:
	return false


## Puts an object on every tile it covers.
func add_object(_object: WorldObject) -> void:
	pass


## Takes the object that covers a tile off the map and returns it, or returns null if there was
## none.
func remove_object(_pos: Vector2i) -> WorldObject:
	return null


## Whether the ground of a tile can be walked on, whatever stands on it: the tile rules (and,
## in the world, the buildings). False where there is no tile.
func is_ground_walkable(pos: Vector2i) -> bool:
	var tile := tile_at(pos)
	return tile != null and tile.is_walkable()


## The ground rules combined with the objects on the tile; a deck (the jetty) is walked on
## whatever the ground under it.
func is_walkable(pos: Vector2i) -> bool:
	var object := object_at(pos)
	if object != null and object.type_data().get("deck", false):
		return true
	if not is_ground_walkable(pos):
		return false
	return object == null or not object.blocks_walking()


## Whether a farm animal can walk on a tile: as anyone can (see `is_walkable`), but not onto what
## stops animals (WorldObjectTypes `stops_animals`). The animals ask it at every step, so it looks
## at the object once.
func is_walkable_for_animals(pos: Vector2i) -> bool:
	var object := object_at(pos)
	if object == null:
		return is_ground_walkable(pos)
	var type := object.type_data()
	if not type.get("deck", false) and not (is_ground_walkable(pos) and not type["blocks_walking"]):
		return false
	return not type.get("stops_animals", false)
