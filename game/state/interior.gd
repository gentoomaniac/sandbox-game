class_name Interior
extends GameMap
## The inside of one building: a small grid of tiles and the objects in it, in its own
## coordinates with (0, 0) at the top left. It is made from a Tiled map (see InteriorLoader);
## everything after that, such as objects added later, is state kept here.

var size := Vector2i.ZERO
## Walking onto this tile leaves the building.
var exit_tile := Vector2i.ZERO
var _tiles: Dictionary[Vector2i, Tile] = {}
var _objects: Dictionary[Vector2i, WorldObject] = {}


## Where the player appears when they come in: the tile next to the exit, into the room.
func entry_tile() -> Vector2i:
	return exit_tile + Vector2i.UP


func tile_at(pos: Vector2i) -> Tile:
	return _tiles.get(pos)


func object_at(pos: Vector2i) -> WorldObject:
	return _objects.get(pos)


func set_terrain(pos: Vector2i, terrain: Tile.Terrain) -> void:
	var tile := Tile.new()
	tile.terrain = terrain
	_tiles[pos] = tile


func add_object(object: WorldObject) -> void:
	assert(not _objects.has(object.pos), "Interior tile %s is taken" % object.pos)
	_objects[object.pos] = object


func objects() -> Array[WorldObject]:
	return _objects.values()
