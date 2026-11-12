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

## What lies on the ground of this map (see `drop_items`).
var ground_items := GroundItems.new()


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


## Whether a tile is under the water of the tide: tidal mud at high enough water. None in a map
## without a tide. Such a tile is not walkable (see `is_ground_walkable` of World), but someone who
## already stands in the water may go on over it (see `is_wadeable`).
func is_flooded(_pos: Vector2i) -> bool:
	return false


## Whether someone who stands on a flooded tile may step onto this one: flooded, and walkable but
## for the water. The rising tide cuts no one off from the shore.
func is_wadeable(_pos: Vector2i) -> bool:
	return false


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


## Whether a pile of dropped items can lie on a tile: where the player can walk.
func can_hold_pile(pos: Vector2i) -> bool:
	return is_walkable(pos)


## Where piles can lie when no tile near their source can hold one, nearest to `source` first.
## None by default: the pile then lies on the source.
func far_pile_tiles(_source: Vector2i) -> Array[Vector2i]:
	return []


## What makes the placing of piles differ from map to map (see `GroundItems.drop`).
func pile_seed() -> int:
	return 0


## Puts items (item id to count) on the ground around a tile (see `GroundItems.drop`). The one
## entry point for whatever gives items to a map; it is here, and not on `ground_items`, because
## where a pile can lie is up to the map's terrain and objects. Returns the piles.
func drop_items(source: Vector2i, drops: Dictionary) -> Array[GroundItem]:
	return ground_items.drop(source, drops, self)
