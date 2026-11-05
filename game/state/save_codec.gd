class_name SaveCodec
extends RefCounted
## What the to_dict / from_dict methods of the state classes share. A save is plain
## JSON-compatible values: numbers, strings, arrays, dictionaries, null. Enums are written by
## name, so reordering an enum does not corrupt old saves.


static func vector_to_json(vector: Vector2i) -> Array:
	return [vector.x, vector.y]


static func vector_from_json(array: Array) -> Vector2i:
	return Vector2i(int(array[0]), int(array[1]))


static func float_vector_to_json(vector: Vector2) -> Array:
	return [vector.x, vector.y]


static func float_vector_from_json(array: Array) -> Vector2:
	return Vector2(array[0], array[1])


static func terrain_to_json(terrain: Tile.Terrain) -> String:
	return Tile.Terrain.keys()[terrain]


static func terrain_from_json(terrain_name: String) -> Tile.Terrain:
	assert(Tile.Terrain.has(terrain_name), "Unknown terrain in save: %s" % terrain_name)
	return Tile.Terrain[terrain_name]
