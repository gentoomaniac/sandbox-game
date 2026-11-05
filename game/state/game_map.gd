class_name GameMap
extends RefCounted
## A place the player can walk around in: the world or the inside of a building. Both are
## made of Tile state and WorldObjects, so walking and sleeping work the same on either. A
## subclass says where its tiles and objects are.


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


## Tile rules combined with the objects on the tile. False where there is no tile.
func is_walkable(pos: Vector2i) -> bool:
	var tile := tile_at(pos)
	if tile == null or not tile.is_walkable():
		return false
	var object := object_at(pos)
	return object == null or not object.blocks_walking()
