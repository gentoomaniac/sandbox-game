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


func to_dict() -> Dictionary:
	var tiles: Array[Array] = []
	for pos in _tiles:
		tiles.append(
			SaveCodec.vector_to_json(pos) + [SaveCodec.terrain_to_json(_tiles[pos].terrain)]
		)
	var objects_data: Array[Dictionary] = []
	for object in _objects.values():
		objects_data.append(object.to_dict())
	return {
		"size": SaveCodec.vector_to_json(size),
		"exit_tile": SaveCodec.vector_to_json(exit_tile),
		"tiles": tiles,
		"objects": objects_data,
	}


## Only the terrain of the tiles is saved: the rest of a tile's state is unused inside.
static func from_dict(data: Dictionary) -> Interior:
	var interior := Interior.new()
	interior.size = SaveCodec.vector_from_json(data["size"])
	interior.exit_tile = SaveCodec.vector_from_json(data["exit_tile"])
	for tile: Array in data["tiles"]:
		interior.set_terrain(SaveCodec.vector_from_json(tile), SaveCodec.terrain_from_json(tile[2]))
	for object_data: Dictionary in data["objects"]:
		interior.add_object(WorldObject.from_dict(object_data))
	return interior
